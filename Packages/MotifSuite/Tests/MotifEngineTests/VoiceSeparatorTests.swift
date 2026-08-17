//
//  VoiceSeparatorTests.swift
//  MotifEngineTests
//

import XCTest
@testable import MotifEngine
import MotifAlgebra

final class VoiceSeparatorTests: XCTestCase {

    private let tpq = 480

    private func note(_ pitch: Int,
                      at beat: Int,
                      length: Int = 1,
                      channel: Int = 0) -> RawMIDINote {
        RawMIDINote(pitch: pitch,
                    onsetTicks: beat * tpq,
                    durationTicks: length * tpq,
                    velocity: 64,
                    channel: channel,
                    track: 0)
    }

    // MARK: - Channel path

    func testChannelSplitPutsHigherAverageOnTop() {
        let notes = [
            note(72, at: 0, channel: 0), note(74, at: 1, channel: 0),
            note(48, at: 0, channel: 1), note(50, at: 1, channel: 1)
        ]

        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)

        XCTAssertEqual(result.method, .channel)
        XCTAssertEqual(result.upper.map(\.pitch).sorted(), [72, 74])
        XCTAssertEqual(result.lower.map(\.pitch).sorted(), [48, 50])
    }

    /// The channel ordering must not depend on which channel number happens to be lower.
    /// AMT005 took `sortedChannels[0]` as voice one and then swapped afterwards; the result was
    /// the same, but only because of the corrective swap. Here the ranking is by register from
    /// the start.
    func testChannelSplitIgnoresChannelNumbering() {
        let notes = [
            note(48, at: 0, channel: 0), note(50, at: 1, channel: 0),
            note(72, at: 0, channel: 1), note(74, at: 1, channel: 1)
        ]

        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)
        XCTAssertEqual(result.upper.map(\.pitch).sorted(), [72, 74])
        XCTAssertEqual(result.lower.map(\.pitch).sorted(), [48, 50])
    }

    /// AMT005 read only the first two channels and dropped the rest. A three-channel file lost
    /// a channel's worth of notes outright.
    func testThirdChannelIsNotDiscarded() {
        let notes = [
            note(72, at: 0, channel: 0),
            note(60, at: 0, channel: 1),
            note(48, at: 0, channel: 2)
        ]

        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)

        XCTAssertEqual(result.upper.count + result.lower.count, 3,
                       "every note must land in some voice")
        XCTAssertEqual((result.upper + result.lower).map(\.pitch).sorted(), [48, 60, 72])
    }

    // MARK: - Greedy path

    func testSingleChannelUsesGreedyPath() {
        let notes = (0 ..< 6).map { note(60 + $0, at: $0) }
        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)
        XCTAssertEqual(result.method, .greedyWithLookAhead)
    }

    /// Two interleaved registers on one channel should come apart.
    func testInterleavedRegistersSeparate() {
        var notes: [RawMIDINote] = []
        for beat in 0 ..< 8 {
            notes.append(note(72 + (beat % 3), at: beat))    // upper line
            notes.append(note(48 + (beat % 3), at: beat))    // lower line
        }

        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)

        XCTAssertEqual(result.upper.count + result.lower.count, notes.count)
        let upperAverage = Double(result.upper.reduce(0) { $0 + $1.pitch }) / Double(result.upper.count)
        let lowerAverage = Double(result.lower.reduce(0) { $0 + $1.pitch }) / Double(result.lower.count)
        XCTAssertGreaterThan(upperAverage, lowerAverage + 12,
                             "the two registers should be more than an octave apart on average")
    }

    func testEveryNoteIsAssignedExactlyOnce() {
        var notes: [RawMIDINote] = []
        for beat in 0 ..< 20 {
            notes.append(note(60 + (beat * 7) % 24, at: beat))
        }

        let result = VoiceSeparator(ticksPerQuarter: tpq).separate(notes)

        let assigned = (result.upper + result.lower)
            .map { "\($0.pitch)@\($0.onsetTicks)" }
            .sorted()
        let original = notes
            .map { "\($0.pitch)@\($0.onsetTicks)" }
            .sorted()

        XCTAssertEqual(assigned, original)
    }

    func testSeparationIsDeterministic() {
        let notes = (0 ..< 24).map { note(55 + ($0 * 5) % 20, at: $0) }
        let separator = VoiceSeparator(ticksPerQuarter: tpq)

        let first = separator.separate(notes)
        let second = separator.separate(notes)

        XCTAssertEqual(first.upper.map(\.pitch), second.upper.map(\.pitch))
        XCTAssertEqual(first.lower.map(\.pitch), second.lower.map(\.pitch))
    }

    // MARK: - Degenerate input

    func testEmptyAndSingleNoteInput() {
        let separator = VoiceSeparator(ticksPerQuarter: tpq)

        let empty = separator.separate([])
        XCTAssertTrue(empty.upper.isEmpty)
        XCTAssertTrue(empty.lower.isEmpty)

        let single = separator.separate([note(60, at: 0)])
        XCTAssertEqual(single.upper.count + single.lower.count, 1)
    }

    // MARK: - Parameters are actually consulted

    /// AMT005 stored a parameters object and then read every threshold from a private `Config`
    /// enum instead, so the parameter had no effect whatsoever. Changing a penalty here must
    /// change something.
    func testParametersChangeTheOutcome() {
        var notes: [RawMIDINote] = []
        for beat in 0 ..< 12 {
            notes.append(note(60 + (beat % 2 == 0 ? 14 : 0), at: beat))
        }

        let permissive = VoiceSeparator.Parameters(crossingPenalty: 0,
                                                   leapPenalty: 0,
                                                   stepPenalty: 0,
                                                   extremeCrossingPenalty: 0,
                                                   registerBias: 0)
        let strict = VoiceSeparator.Parameters(crossingPenalty: 100,
                                               leapPenalty: 50,
                                               registerBias: 20)

        let a = VoiceSeparator(ticksPerQuarter: tpq, parameters: permissive).separate(notes)
        let b = VoiceSeparator(ticksPerQuarter: tpq, parameters: strict).separate(notes)

        XCTAssertNotEqual(a.upper.map(\.pitch), b.upper.map(\.pitch),
                          "penalties must influence the assignment")
    }
}
