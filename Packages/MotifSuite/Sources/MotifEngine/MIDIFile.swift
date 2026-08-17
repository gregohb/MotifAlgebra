//
//  MIDIFile.swift
//  MotifEngine
//
//  Standard MIDI File parsing, ported from AMT005's MPHeaderParser / MPTrackParser / MPMIDIParser.
//
//  One change dominates all the others: TIME IS ACCUMULATED IN TICKS, AS Int.
//
//  AMT005 converted each delta time to beats the moment it read it —
//
//      currentTime += Double(deltaTime) / Double(ticksPerQuarter)
//
//  — which is a division per event, each one rounding, all of them accumulating. A triplet
//  eighth in a 480-tick file is 160/480; in Double that is 0.33333333333333331, and after a few
//  hundred events the onsets no longer land on any exact grid. Rational.init(approximating:)
//  could recover a nearby fraction afterwards, but only by guessing at what the rounding
//  destroyed.
//
//  There is nothing to recover, because nothing needs to be lost. A MIDI file's time base is
//  already rational: ticks over ticks-per-quarter, both integers, exactly. Accumulate the
//  integer and divide once, at the end, into a Rational. The conversion is exact, and
//  `Rational(approximating:)` — which the algebra's own header warns is for the I/O boundary
//  only — turns out not to be needed at this boundary at all.
//
//  Three correctness fixes came along with the port, all of them things the old parser got
//  wrong on real files rather than hypotheticals:
//
//    * Active notes are keyed by (channel, pitch), not pitch alone. AMT005 used a bare
//      [Int: ...] keyed on pitch, so a note-on for pitch 60 on channel 1 silently evicted a
//      sounding pitch 60 on channel 0 — the first note lost its note-off and got swept up by
//      the end-of-track cleanup with a fabricated duration. Any two-hand keyboard part voiced
//      across two channels hit this.
//    * Meta and SysEx events clear running status, as the specification requires. AMT005 left
//      the previous channel status in place across a meta event, so a track whose first event
//      after a tempo change omitted its status byte was decoded against a stale status.
//    * The header search loop `for i in 0..<(bytes.count - 14)` traps on any file shorter than
//      14 bytes, since the range is formed before the count is checked. An empty or truncated
//      file crashed rather than failing.
//
//  Durations are left exactly as the file states them, including zero. AMT005 clamped them to
//  `max(0.1, ...)` and dangling notes to `max(0.5, ...)`; those floors are inventions, and a
//  fabricated duration is worse than a diagnosed one. Anything irregular is reported through
//  `diagnostics` and left for the caller to decide about.
//

import Foundation
import MotifAlgebra

// MARK: - Raw note

/// A note as the file states it: sounding MIDI number, integer ticks, no interpretation.
///
/// Deliberately not a `Note`. Spelling a pitch and choosing a `Space` are decisions that need
/// musical context this layer does not have, so they happen one level up, in `MIDIImport`.
public struct RawMIDINote: Hashable, Sendable {

    public var pitch: Int
    public var onsetTicks: Int
    public var durationTicks: Int
    public var velocity: Int
    public var channel: Int
    public var track: Int

    public init(pitch: Int,
                onsetTicks: Int,
                durationTicks: Int,
                velocity: Int,
                channel: Int,
                track: Int) {
        self.pitch = pitch
        self.onsetTicks = onsetTicks
        self.durationTicks = durationTicks
        self.velocity = velocity
        self.channel = channel
        self.track = track
    }

    public var endTicks: Int { onsetTicks + durationTicks }
}

// MARK: - Diagnostics

/// Something irregular in the file. Reported, never silently repaired.
///
/// This replaces AMT005's forty-odd `print` calls. A parser that prints cannot be tested on its
/// warnings, and a parser that repairs silently cannot be trusted on its output.
public struct MIDIDiagnostic: Hashable, Sendable, CustomStringConvertible {

    public enum Kind: Hashable, Sendable {
        case unpairedNoteOn(pitch: Int, channel: Int, track: Int)
        case unmatchedNoteOff(pitch: Int, channel: Int, track: Int)
        case zeroLengthNote(pitch: Int, channel: Int, track: Int)
        case runningStatusWithoutPrecedent(track: Int, offset: Int)
        case unknownEvent(status: UInt8, track: Int, offset: Int)
        case truncatedEvent(track: Int, offset: Int)
        case smpteTimeCode(assumedTicksPerQuarter: Int)
        case skippedChunk(type: String, bytes: Int)
        case trackCountMismatch(declared: Int, found: Int)
    }

    public var kind: Kind

    public init(_ kind: Kind) { self.kind = kind }

    public var description: String {
        switch kind {
        case let .unpairedNoteOn(p, c, t):
            return "track \(t): note-on for pitch \(p) on channel \(c) never ended; closed at end of track"
        case let .unmatchedNoteOff(p, c, t):
            return "track \(t): note-off for pitch \(p) on channel \(c) with nothing sounding"
        case let .zeroLengthNote(p, c, t):
            return "track \(t): pitch \(p) on channel \(c) has zero duration"
        case let .runningStatusWithoutPrecedent(t, o):
            return "track \(t), offset \(o): running status used with no preceding status byte"
        case let .unknownEvent(s, t, o):
            return "track \(t), offset \(o): unrecognised status byte 0x\(String(s, radix: 16, uppercase: true))"
        case let .truncatedEvent(t, o):
            return "track \(t), offset \(o): event runs past the end of the chunk"
        case let .smpteTimeCode(assumed):
            return "file uses SMPTE time code; assuming \(assumed) ticks per quarter"
        case let .skippedChunk(type, bytes):
            return "skipped \(bytes)-byte chunk of type '\(type)'"
        case let .trackCountMismatch(declared, found):
            return "header declares \(declared) tracks, file contains \(found)"
        }
    }
}

public enum MIDIParseError: Error, CustomStringConvertible {
    case tooShort
    case missingHeaderChunk
    case badHeaderLength(Int)
    case badDivision

    public var description: String {
        switch self {
        case .tooShort: return "file is too short to contain a MIDI header"
        case .missingHeaderChunk: return "no MThd chunk found"
        case let .badHeaderLength(n): return "MThd declares a length of \(n); expected at least 6"
        case .badDivision: return "MThd declares a zero division"
        }
    }
}

// MARK: - Parsed file

public struct MIDIFile: Sendable {

    public var format: Int
    public var declaredTrackCount: Int
    public var ticksPerQuarter: Int
    public var notes: [RawMIDINote]
    public var diagnostics: [MIDIDiagnostic]

    /// Exact musical time of a tick count, in quarter notes. Never approximate.
    public func beats(ofTicks ticks: Int) -> Rational {
        Rational(ticks, ticksPerQuarter)
    }

    // MARK: Parsing

    public init(bytes: [UInt8]) throws {
        guard bytes.count >= 14 else { throw MIDIParseError.tooShort }

        var diagnostics: [MIDIDiagnostic] = []

        // Locate MThd. Almost always at offset 0, but some files carry a wrapper ahead of it.
        // The `- 14` here is safe only because of the count check above; AMT005's equivalent
        // was not guarded and trapped on short input.
        var headerStart: Int?
        for i in 0 ... (bytes.count - 14) where Self.matches("MThd", in: bytes, at: i) {
            headerStart = i
            break
        }
        guard let h = headerStart else { throw MIDIParseError.missingHeaderChunk }

        let headerLength = Self.readUInt32(bytes, at: h + 4)
        guard headerLength >= 6 else { throw MIDIParseError.badHeaderLength(headerLength) }

        self.format = Self.readUInt16(bytes, at: h + 8)
        self.declaredTrackCount = Self.readUInt16(bytes, at: h + 10)

        let division = Self.readUInt16(bytes, at: h + 12)
        guard division != 0 else { throw MIDIParseError.badDivision }

        if division & 0x8000 != 0 {
            // SMPTE: the upper byte is a negative frame rate, the lower is ticks per frame.
            // AMT005 substituted 480 and printed a line. Substituting is still the only sane
            // option without a tempo map, but it is now reported rather than announced to stdout.
            self.ticksPerQuarter = 480
            diagnostics.append(MIDIDiagnostic(.smpteTimeCode(assumedTicksPerQuarter: 480)))
        } else {
            self.ticksPerQuarter = division & 0x7FFF
        }

        // Walk the chunks after the header.
        var notes: [RawMIDINote] = []
        var position = h + 8 + headerLength
        var trackIndex = 0

        while position + 8 <= bytes.count {
            let type = Self.chunkType(bytes, at: position)
            let length = Self.readUInt32(bytes, at: position + 4)
            let bodyStart = position + 8
            let bodyEnd = min(bodyStart + length, bytes.count)

            if type == "MTrk" {
                let parsed = Self.parseTrack(bytes,
                                             from: bodyStart,
                                             to: bodyEnd,
                                             track: trackIndex,
                                             diagnostics: &diagnostics)
                notes.append(contentsOf: parsed)
                trackIndex += 1
            } else {
                diagnostics.append(MIDIDiagnostic(.skippedChunk(type: type, bytes: length)))
            }

            position = bodyStart + length
            if length <= 0 { break }   // a zero-length chunk would spin the loop forever
        }

        if trackIndex != declaredTrackCount {
            diagnostics.append(MIDIDiagnostic(.trackCountMismatch(declared: declaredTrackCount,
                                                                 found: trackIndex)))
        }

        // Deterministic order. Onset first, then pitch, so two runs over the same bytes produce
        // the same array — the parser feeds equality comparisons downstream.
        self.notes = notes.sorted {
            if $0.onsetTicks != $1.onsetTicks { return $0.onsetTicks < $1.onsetTicks }
            if $0.pitch != $1.pitch { return $0.pitch < $1.pitch }
            if $0.channel != $1.channel { return $0.channel < $1.channel }
            return $0.track < $1.track
        }
        self.diagnostics = diagnostics
    }

    public init(contentsOf url: URL) throws {
        try self.init(bytes: [UInt8](Data(contentsOf: url)))
    }

    // MARK: Track parsing

    /// Identifies a sounding note. Channel is part of the key — that is the fix described in
    /// the file header.
    private struct VoiceKey: Hashable {
        var channel: Int
        var pitch: Int
    }

    private struct Sounding {
        var onsetTicks: Int
        var velocity: Int
    }

    private static func parseTrack(_ bytes: [UInt8],
                                   from start: Int,
                                   to end: Int,
                                   track: Int,
                                   diagnostics: inout [MIDIDiagnostic]) -> [RawMIDINote] {

        var notes: [RawMIDINote] = []
        var position = start
        var timeTicks = 0
        var runningStatus: UInt8 = 0

        // FIFO per key: a repeated note-on before its note-off is legal, and the first one
        // sounding is the first one ended.
        var sounding: [VoiceKey: [Sounding]] = [:]

        func close(_ key: VoiceKey, at tick: Int) {
            guard var queue = sounding[key], !queue.isEmpty else {
                diagnostics.append(MIDIDiagnostic(
                    .unmatchedNoteOff(pitch: key.pitch, channel: key.channel, track: track)))
                return
            }
            let s = queue.removeFirst()
            sounding[key] = queue.isEmpty ? nil : queue

            let duration = tick - s.onsetTicks
            if duration == 0 {
                diagnostics.append(MIDIDiagnostic(
                    .zeroLengthNote(pitch: key.pitch, channel: key.channel, track: track)))
            }
            notes.append(RawMIDINote(pitch: key.pitch,
                                     onsetTicks: s.onsetTicks,
                                     durationTicks: duration,
                                     velocity: s.velocity,
                                     channel: key.channel,
                                     track: track))
        }

        while position < end {
            let (delta, deltaBytes) = readVariableLength(bytes, at: position, limit: end)
            guard deltaBytes > 0 else {
                diagnostics.append(MIDIDiagnostic(.truncatedEvent(track: track, offset: position)))
                break
            }
            position += deltaBytes
            timeTicks += delta

            guard position < end else {
                diagnostics.append(MIDIDiagnostic(.truncatedEvent(track: track, offset: position)))
                break
            }

            // Running status: a data byte here means "reuse the last channel status".
            var status = bytes[position]
            if status < 0x80 {
                guard runningStatus != 0 else {
                    diagnostics.append(MIDIDiagnostic(
                        .runningStatusWithoutPrecedent(track: track, offset: position)))
                    position += 1
                    continue
                }
                status = runningStatus
            } else {
                position += 1
                // Only channel messages set running status; system messages clear it.
                runningStatus = status < 0xF0 ? status : 0
            }

            let eventType = status & 0xF0
            let channel = Int(status & 0x0F)
            let before = position

            switch eventType {
            case 0x90, 0x80:
                guard position + 1 < end else {
                    diagnostics.append(MIDIDiagnostic(.truncatedEvent(track: track, offset: position)))
                    position = end
                    break
                }
                let pitch = Int(bytes[position] & 0x7F)
                let velocity = Int(bytes[position + 1] & 0x7F)
                let key = VoiceKey(channel: channel, pitch: pitch)

                // Note-on with velocity zero is a note-off. Universally used, and the reason
                // note-on and note-off share a branch here.
                if eventType == 0x90 && velocity > 0 {
                    sounding[key, default: []].append(Sounding(onsetTicks: timeTicks,
                                                               velocity: velocity))
                } else {
                    close(key, at: timeTicks)
                }
                position += 2

            case 0xA0, 0xB0, 0xE0:
                position = min(position + 2, end)

            case 0xC0, 0xD0:
                position = min(position + 1, end)

            case 0xF0:
                position = skipSystemMessage(bytes,
                                             at: position,
                                             limit: end,
                                             status: status,
                                             track: track,
                                             diagnostics: &diagnostics)

            default:
                diagnostics.append(MIDIDiagnostic(
                    .unknownEvent(status: status, track: track, offset: position)))
                position += 1
            }

            // The loop must make progress even when a branch above misbehaves.
            if position <= before { position = before + 1 }
        }

        // Anything still sounding at the end of the track. Closed at the final timestamp, and
        // reported — AMT005 gave these a fabricated half-beat duration instead.
        for (key, queue) in sounding.sorted(by: { ($0.key.channel, $0.key.pitch) < ($1.key.channel, $1.key.pitch) }) {
            for s in queue {
                diagnostics.append(MIDIDiagnostic(
                    .unpairedNoteOn(pitch: key.pitch, channel: key.channel, track: track)))
                notes.append(RawMIDINote(pitch: key.pitch,
                                         onsetTicks: s.onsetTicks,
                                         durationTicks: max(0, timeTicks - s.onsetTicks),
                                         velocity: s.velocity,
                                         channel: key.channel,
                                         track: track))
            }
        }

        return notes
    }

    private static func skipSystemMessage(_ bytes: [UInt8],
                                          at position: Int,
                                          limit end: Int,
                                          status: UInt8,
                                          track: Int,
                                          diagnostics: inout [MIDIDiagnostic]) -> Int {
        var pos = position

        if status == 0xFF {
            guard pos < end else { return end }
            pos += 1                                   // meta type
            let (length, used) = readVariableLength(bytes, at: pos, limit: end)
            guard used > 0 else {
                diagnostics.append(MIDIDiagnostic(.truncatedEvent(track: track, offset: pos)))
                return end
            }
            pos += used
            return min(pos + length, end)
        }

        if status == 0xF0 || status == 0xF7 {
            let (length, used) = readVariableLength(bytes, at: pos, limit: end)
            guard used > 0 else {
                diagnostics.append(MIDIDiagnostic(.truncatedEvent(track: track, offset: pos)))
                return end
            }
            pos += used
            return min(pos + length, end)
        }

        // System common with fixed lengths.
        switch status {
        case 0xF1, 0xF3: return min(pos + 1, end)
        case 0xF2: return min(pos + 2, end)
        default: return pos
        }
    }

    // MARK: Byte utilities

    private static func readVariableLength(_ bytes: [UInt8],
                                           at start: Int,
                                           limit: Int) -> (value: Int, bytesUsed: Int) {
        var value = 0
        var used = 0
        var i = start

        while i < limit && used < 4 {
            let byte = bytes[i]
            value = (value << 7) | Int(byte & 0x7F)
            used += 1
            i += 1
            if byte & 0x80 == 0 { return (value, used) }
        }

        // Ran off the end, or a fifth continuation byte — malformed either way.
        return used < 4 ? (0, 0) : (value, used)
    }

    private static func readUInt32(_ bytes: [UInt8], at position: Int) -> Int {
        guard position + 3 < bytes.count else { return 0 }
        return (Int(bytes[position]) << 24)
             | (Int(bytes[position + 1]) << 16)
             | (Int(bytes[position + 2]) << 8)
             |  Int(bytes[position + 3])
    }

    private static func readUInt16(_ bytes: [UInt8], at position: Int) -> Int {
        guard position + 1 < bytes.count else { return 0 }
        return (Int(bytes[position]) << 8) | Int(bytes[position + 1])
    }

    private static func matches(_ ascii: String, in bytes: [UInt8], at position: Int) -> Bool {
        let want = Array(ascii.utf8)
        guard position + want.count <= bytes.count else { return false }
        for (k, b) in want.enumerated() where bytes[position + k] != b { return false }
        return true
    }

    private static func chunkType(_ bytes: [UInt8], at position: Int) -> String {
        guard position + 4 <= bytes.count else { return "" }
        return String(decoding: bytes[position ..< position + 4], as: UTF8.self)
    }
}
