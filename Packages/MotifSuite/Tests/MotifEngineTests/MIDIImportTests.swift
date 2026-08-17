//
//  MIDIImportTests.swift
//  MotifEngineTests
//
//  These tests build MIDI files byte by byte rather than shipping fixture files. That is not
//  fastidiousness: the properties under test are about specific byte patterns — running status,
//  a meta event between two channel events, two channels sounding the same pitch — and a fixture
//  cannot be pointed at and said to contain exactly one of them.
//
//  The first test is the one that motivated the port.
//

import XCTest
@testable import MotifEngine
import MotifAlgebra

// MARK: - Builder

/// Minimal Standard MIDI File writer, enough to exercise the parser.
private struct MIDIBuilder {

    var ticksPerQuarter: Int = 480
    var format: Int = 1
    private var tracks: [[UInt8]] = []

    static func variableLength(_ value: Int) -> [UInt8] {
        guard value > 0 else { return [0] }
        var buffer: [UInt8] = []
        var v = value
        buffer.append(UInt8(v & 0x7F))
        v >>= 7
        while v > 0 {
            buffer.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        return buffer.reversed()
    }

    mutating func addTrack(_ events: [(delta: Int, bytes: [UInt8])]) {
        var body: [UInt8] = []
        for event in events {
            body += Self.variableLength(event.delta)
            body += event.bytes
        }
        body += Self.variableLength(0) + [0xFF, 0x2F, 0x00]   // end of track
        tracks.append(body)
    }

    func bytes() -> [UInt8] {
        var out: [UInt8] = Array("MThd".utf8)
        out += [0, 0, 0, 6]
        out += [UInt8(format >> 8), UInt8(format & 0xFF)]
        out += [UInt8(tracks.count >> 8), UInt8(tracks.count & 0xFF)]
        out += [UInt8(ticksPerQuarter >> 8), UInt8(ticksPerQuarter & 0xFF)]

        for track in tracks {
            out += Array("MTrk".utf8)
            let n = track.count
            out += [UInt8((n >> 24) & 0xFF), UInt8((n >> 16) & 0xFF),
                    UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)]
            out += track
        }
        return out
    }
}

private func noteOn(_ pitch: UInt8, channel: UInt8 = 0, velocity: UInt8 = 64) -> [UInt8] {
    [0x90 | channel, pitch, velocity]
}

private func noteOff(_ pitch: UInt8, channel: UInt8 = 0) -> [UInt8] {
    [0x80 | channel, pitch, 0]
}

// MARK: - Tests

final class MIDIImportTests: XCTestCase {

    // MARK: Exactness

    /// The reason the parser accumulates ticks instead of beats.
    ///
    /// A triplet eighth at 480 ticks per quarter is 160 ticks, which is exactly one third of a
    /// quarter. AMT005 computed `160.0 / 480.0` and stored 0.33333333333333331. Here the result
    /// must be Rational(1, 3) on the nose, because equality against 1/3 is what the algebra's
    /// invertibility laws are checked with.
    func testTripletTimeIsExactNotApproximate() throws {
        var builder = MIDIBuilder()
        builder.addTrack([
            (0, noteOn(60)),
            (160, noteOff(60)),
            (0, noteOn(62)),
            (160, noteOff(62)),
            (0, noteOn(64)),
            (160, noteOff(64))
        ])

        let file = try MIDIFile(bytes: builder.bytes())
        XCTAssertEqual(file.notes.count, 3)

        let third = Rational(1, 3)
        XCTAssertEqual(file.beats(ofTicks: file.notes[0].durationTicks), third)
        XCTAssertEqual(file.beats(ofTicks: file.notes[1].onsetTicks), third)
        XCTAssertEqual(file.beats(ofTicks: file.notes[2].onsetTicks), Rational(2, 3))

        // And the exactness survives into the algebra's own types.
        let result = MIDIImport(space: .cMajor).imported(file)
        XCTAssertEqual(result.combined.notes.map(\.onset),
                       [Rational(0), third, Rational(2, 3)])

        // Three of them make exactly one quarter. In Double this sum is 0.99999999999999989.
        let total = third + third + third
        XCTAssertEqual(total, Rational(1))
    }

    /// Ticks divide exactly no matter how awkward the tick base.
    func testUnusualTickBaseStillDividesExactly() throws {
        var builder = MIDIBuilder()
        builder.ticksPerQuarter = 96
        builder.addTrack([(0, noteOn(60)), (32, noteOff(60))])

        let file = try MIDIFile(bytes: builder.bytes())
        XCTAssertEqual(file.ticksPerQuarter, 96)
        XCTAssertEqual(file.beats(ofTicks: file.notes[0].durationTicks), Rational(1, 3))
    }

    // MARK: The channel-collision bug

    /// AMT005 keyed sounding notes on pitch alone, so this file decoded wrongly.
    ///
    /// Two channels hold middle C at overlapping times. With a pitch-only key, the second
    /// note-on overwrites the first's entry, the first note-off closes the *second* note, and
    /// the first is left dangling to be swept up at end of track with an invented duration.
    /// Keyed on (channel, pitch), both notes come out with the durations the file states.
    func testOverlappingSamePitchOnTwoChannels() throws {
        var builder = MIDIBuilder()
        builder.addTrack([
            (0,   noteOn(60, channel: 0)),
            (240, noteOn(60, channel: 1)),
            (240, noteOff(60, channel: 0)),   // t = 480
            (240, noteOff(60, channel: 1))    // t = 720
        ])

        let file = try MIDIFile(bytes: builder.bytes())

        XCTAssertEqual(file.notes.count, 2)
        XCTAssertTrue(file.diagnostics.isEmpty,
                      "nothing about this file is irregular: \(file.diagnostics)")

        let channel0 = try XCTUnwrap(file.notes.first { $0.channel == 0 })
        let channel1 = try XCTUnwrap(file.notes.first { $0.channel == 1 })

        XCTAssertEqual(channel0.onsetTicks, 0)
        XCTAssertEqual(channel0.durationTicks, 480)
        XCTAssertEqual(channel1.onsetTicks, 240)
        XCTAssertEqual(channel1.durationTicks, 480)
    }

    /// The same pitch struck twice on one channel before either ends pairs first-in-first-out.
    func testRepeatedNoteOnSameChannelPairsInOrder() throws {
        var builder = MIDIBuilder()
        builder.addTrack([
            (0,   noteOn(60)),
            (120, noteOn(60)),
            (120, noteOff(60)),   // t = 240, closes the first
            (240, noteOff(60))    // t = 480, closes the second
        ])

        let file = try MIDIFile(bytes: builder.bytes())
        XCTAssertEqual(file.notes.count, 2)

        let sorted = file.notes.sorted { $0.onsetTicks < $1.onsetTicks }
        XCTAssertEqual(sorted[0].onsetTicks, 0)
        XCTAssertEqual(sorted[0].durationTicks, 240)
        XCTAssertEqual(sorted[1].onsetTicks, 120)
        XCTAssertEqual(sorted[1].durationTicks, 360)
    }

    // MARK: Running status

    func testRunningStatusIsHonoured() throws {
        var builder = MIDIBuilder()
        // One status byte, then bare data pairs.
        builder.addTrack([
            (0,   [0x90, 60, 64]),
            (240, [62, 64]),
            (240, [64, 64]),
            (240, [60, 0]),
            (0,   [62, 0]),
            (0,   [64, 0])
        ])

        let file = try MIDIFile(bytes: builder.bytes())
        XCTAssertEqual(file.notes.count, 3)
        XCTAssertEqual(file.notes.map(\.pitch).sorted(), [60, 62, 64])
        XCTAssertTrue(file.diagnostics.isEmpty, "\(file.diagnostics)")
    }

    /// A meta event clears running status, per the specification. AMT005 did not clear it, so
    /// a track that resumed with a bare data pair after a tempo change decoded against a stale
    /// status byte. Here the bare pair after the meta event is correctly rejected rather than
    /// silently misread as a note.
    func testMetaEventClearsRunningStatus() throws {
        var builder = MIDIBuilder()
        builder.addTrack([
            (0,   [0x90, 60, 64]),
            (0,   [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]),   // set tempo
            (240, [62, 64])                                 // bare pair — now illegal
        ])

        let file = try MIDIFile(bytes: builder.bytes())

        let sawRunningStatusComplaint = file.diagnostics.contains {
            if case .runningStatusWithoutPrecedent = $0.kind { return true }
            return false
        }
        XCTAssertTrue(sawRunningStatusComplaint,
                      "expected the bare data pair after a meta event to be rejected")
        XCTAssertFalse(file.notes.contains { $0.pitch == 62 },
                       "pitch 62 was decoded from a stale running status")
    }

    // MARK: Diagnostics rather than repairs

    func testZeroLengthNoteIsReportedNotClamped() throws {
        var builder = MIDIBuilder()
        builder.addTrack([(0, noteOn(60)), (0, noteOff(60))])

        let file = try MIDIFile(bytes: builder.bytes())

        XCTAssertEqual(file.notes.count, 1)
        XCTAssertEqual(file.notes[0].durationTicks, 0,
                       "AMT005 clamped this to 0.1 beats; the file says zero")
        XCTAssertTrue(file.diagnostics.contains {
            if case .zeroLengthNote = $0.kind { return true }
            return false
        })
    }

    func testDanglingNoteOnIsReported() throws {
        var builder = MIDIBuilder()
        builder.addTrack([(0, noteOn(60)), (480, noteOn(64)), (480, noteOff(64))])

        let file = try MIDIFile(bytes: builder.bytes())

        XCTAssertTrue(file.diagnostics.contains {
            if case .unpairedNoteOn = $0.kind { return true }
            return false
        })
        let dangling = try XCTUnwrap(file.notes.first { $0.pitch == 60 })
        XCTAssertEqual(dangling.durationTicks, 960, "closed at the final timestamp, not invented")
    }

    func testUnmatchedNoteOffIsReported() throws {
        var builder = MIDIBuilder()
        builder.addTrack([(0, noteOff(60))])

        let file = try MIDIFile(bytes: builder.bytes())
        XCTAssertTrue(file.notes.isEmpty)
        XCTAssertTrue(file.diagnostics.contains {
            if case .unmatchedNoteOff = $0.kind { return true }
            return false
        })
    }

    // MARK: Malformed input

    /// AMT005 formed the range `0..<(bytes.count - 14)` before checking the count, so this
    /// input trapped instead of failing.
    func testShortFileThrowsRatherThanTrapping() {
        XCTAssertThrowsError(try MIDIFile(bytes: [0x4D, 0x54, 0x68, 0x64]))
        XCTAssertThrowsError(try MIDIFile(bytes: []))
    }

    func testFileWithoutHeaderChunkThrows() {
        XCTAssertThrowsError(try MIDIFile(bytes: [UInt8](repeating: 0, count: 64)))
    }

    func testTruncatedTrackDoesNotHang() throws {
        var builder = MIDIBuilder()
        builder.addTrack([(0, noteOn(60)), (240, noteOff(60))])
        var bytes = builder.bytes()
        bytes.removeLast(4)                       // chop the end-of-track meta event

        // The declared chunk length now overruns the buffer; parsing must terminate.
        let file = try MIDIFile(bytes: bytes)
        XCTAssertLessThanOrEqual(file.notes.count, 1)
    }

    // MARK: Round trip

    /// Spelling is a guess; sounding pitch is not. Whatever the importer spells, the MIDI number
    /// it sounds must be the byte that was in the file.
    func testImportPreservesSoundingPitchAndTime() throws {
        var builder = MIDIBuilder()
        builder.addTrack([
            (0,   noteOn(60)), (240, noteOff(60)),
            (0,   noteOn(63)), (240, noteOff(63)),   // E-flat: not in C major
            (0,   noteOn(67)), (240, noteOff(67)),
            (0,   noteOn(70)), (240, noteOff(70))    // B-flat: not in C major either
        ])

        let file = try MIDIFile(bytes: builder.bytes())
        let importer = MIDIImport(space: .cMajor)
        let result = importer.imported(file)

        XCTAssertTrue(importer.soundsIdentical(result, to: file))
        XCTAssertEqual(result.combined.midis.sorted(), [60, 63, 67, 70])
    }

    /// The same music imported against the wrong key still sounds right and spells differently.
    /// This is the distinction the round-trip check exists to draw.
    func testWrongSpaceChangesSpellingButNotSound() throws {
        var builder = MIDIBuilder()
        builder.addTrack([(0, noteOn(63)), (240, noteOff(63))])
        let file = try MIDIFile(bytes: builder.bytes())

        let inC = MIDIImport(space: .cMajor)
        let inEFlat = MIDIImport(space: .major(3))

        let fromC = inC.imported(file)
        let fromEFlat = inEFlat.imported(file)

        XCTAssertTrue(inC.soundsIdentical(fromC, to: file))
        XCTAssertTrue(inEFlat.soundsIdentical(fromEFlat, to: file))

        XCTAssertEqual(fromC.combined.midis, fromEFlat.combined.midis,
                       "the sound must not depend on the space")
        XCTAssertNotEqual(fromC.combined.notes[0].pitch,
                          fromEFlat.combined.notes[0].pitch,
                          "the spelling should")
    }
}
