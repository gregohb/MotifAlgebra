//
//  VoiceSeparator.swift
//  MotifEngine
//
//  Two-voice separation, ported from AMT005's MPVoiceSeparator.
//
//  The algorithm is kept: split on channel when the file already says which voice is which,
//  otherwise walk the notes in time order assigning each to whichever voice costs less, where
//  cost penalises leaps, silences, and voice crossings, with a look-ahead term that pulls a note
//  toward the register it is about to be in.
//
//  What is NOT kept is the claim that this is dynamic programming. AMT005's method was named
//  `separateWithDynamicProgramming` and printed "Using dynamic programming for voice
//  separation", but it never built a table and never revisited a decision: each note is assigned
//  once, greedily, from the state left by its predecessor. That is a greedy assignment with
//  look-ahead, which is a perfectly reasonable thing to do and a completely different thing from
//  what it was called. The name mattered because it discouraged anyone from asking whether a
//  wrong early assignment could be recovered from. It cannot. So it is called what it is, and
//  `Parameters` is exposed so the penalties can be tuned by experiment rather than by editing a
//  private enum.
//
//  Two substantive changes:
//
//    * Time is Rational throughout. The old cost function compared `timeDiff > 2.0` against
//      Doubles derived from divided ticks; here the comparison is exact, so a rest that is
//      exactly two beats classifies the same way on every file regardless of its tick base.
//    * The old class stored a `DSVoiceSeparationParameters` and then never read it — every
//      threshold came from a private `Config` enum, so the parameter object in the initialiser
//      was dead. Passing `.enhanced` versus anything else changed nothing. `Parameters` here is
//      actually consulted.
//
//  Separation runs on sounding MIDI numbers, before spelling. That ordering is deliberate:
//  which voice a note belongs to is a question about register and continuity, and cannot depend
//  on whether it is written C-sharp or D-flat.
//

import Foundation
import MotifAlgebra

public struct VoiceSeparator {

    public struct Parameters: Sendable {

        /// How far ahead the look-ahead term looks, in quarter notes.
        public var lookAhead: Rational

        /// Charged when a note lands on the far side of the other voice from its predecessor.
        public var crossingPenalty: Double

        /// Per-semitone charge for a leap wider than `maxComfortableLeap`.
        public var leapPenalty: Double

        /// Per-semitone charge for any motion at all, so that smaller steps are preferred.
        public var stepPenalty: Double

        /// Per-beat charge for a rest longer than `maxComfortableRest`.
        public var silencePenalty: Double

        /// Charge for a voice moving more than an octave past the other voice.
        public var extremeCrossingPenalty: Double

        /// Pull toward the register the voice is about to occupy.
        public var lookAheadWeight: Double

        /// Bias applied by the note's position relative to the piece's average pitch.
        public var registerBias: Double

        public var maxComfortableLeap: Int
        public var maxComfortableRest: Rational

        public init(lookAhead: Rational = Rational(2),
                    crossingPenalty: Double = 5.0,
                    leapPenalty: Double = 1.0,
                    stepPenalty: Double = 0.1,
                    silencePenalty: Double = 0.5,
                    extremeCrossingPenalty: Double = 10.0,
                    lookAheadWeight: Double = 0.05,
                    registerBias: Double = 2.0,
                    maxComfortableLeap: Int = 12,
                    maxComfortableRest: Rational = Rational(2)) {
            self.lookAhead = lookAhead
            self.crossingPenalty = crossingPenalty
            self.leapPenalty = leapPenalty
            self.stepPenalty = stepPenalty
            self.silencePenalty = silencePenalty
            self.extremeCrossingPenalty = extremeCrossingPenalty
            self.lookAheadWeight = lookAheadWeight
            self.registerBias = registerBias
            self.maxComfortableLeap = maxComfortableLeap
            self.maxComfortableRest = maxComfortableRest
        }

        /// AMT005's `Config` values, which were the ones actually in force there.
        public static let standard = Parameters()
    }

    public struct Result: Sendable {
        /// The upper voice by average pitch.
        public var upper: [RawMIDINote]
        /// The lower voice by average pitch.
        public var lower: [RawMIDINote]
        /// How the split was arrived at — worth surfacing, since the two paths are very different.
        public var method: Method

        public enum Method: String, Sendable {
            case channel
            case greedyWithLookAhead
            case trivial
        }
    }

    public var parameters: Parameters
    public var ticksPerQuarter: Int

    public init(ticksPerQuarter: Int, parameters: Parameters = .standard) {
        self.ticksPerQuarter = ticksPerQuarter
        self.parameters = parameters
    }

    private func beats(_ ticks: Int) -> Rational { Rational(ticks, ticksPerQuarter) }

    // MARK: - Entry point

    public func separate(_ notes: [RawMIDINote]) -> Result {
        guard notes.count > 1 else {
            return Result(upper: notes, lower: [], method: .trivial)
        }

        let byChannel = Dictionary(grouping: notes, by: \.channel)

        let split: ([RawMIDINote], [RawMIDINote])
        let method: Result.Method

        if byChannel.count >= 2 {
            split = separateByChannel(byChannel)
            method = .channel
        } else {
            split = separateGreedily(notes)
            method = .greedyWithLookAhead
        }

        let ordered = orderByRegister(split.0, split.1)
        return Result(upper: ordered.0, lower: ordered.1, method: method)
    }

    // MARK: - Channel split

    /// When more than two channels are present, everything above the second is folded into the
    /// nearer of the two by average pitch. AMT005 simply dropped channels three and up on the
    /// floor — `sortedChannels[0]` and `[1]` were taken and the rest never referenced, so a
    /// three-stave import silently lost a stave.
    private func separateByChannel(_ groups: [Int: [RawMIDINote]]) -> ([RawMIDINote], [RawMIDINote]) {
        let ranked = groups
            .map { (channel: $0.key, notes: $0.value, average: averagePitch($0.value)) }
            .sorted { $0.average > $1.average }

        guard let highest = ranked.first, let lowest = ranked.last, ranked.count >= 2 else {
            return (ranked.first?.notes ?? [], [])
        }

        var upper = highest.notes
        var lower = lowest.notes

        for group in ranked.dropFirst().dropLast() {
            if abs(group.average - highest.average) <= abs(group.average - lowest.average) {
                upper.append(contentsOf: group.notes)
            } else {
                lower.append(contentsOf: group.notes)
            }
        }

        return (upper, lower)
    }

    // MARK: - Greedy assignment

    private func separateGreedily(_ notes: [RawMIDINote]) -> ([RawMIDINote], [RawMIDINote]) {
        let sorted = notes.sorted {
            if $0.onsetTicks != $1.onsetTicks { return $0.onsetTicks < $1.onsetTicks }
            return $0.pitch > $1.pitch          // higher pitch first within a chord
        }

        let average = averagePitch(sorted)

        var voiceA: [RawMIDINote] = []          // the one that tends higher
        var voiceB: [RawMIDINote] = []
        var lastA: RawMIDINote?
        var lastB: RawMIDINote?

        var index = 0
        while index < sorted.count {
            // Everything struck at the same instant is decided together, top-down. A chord split
            // note-by-note against a cost function produces crossings the ear never hears.
            let onset = sorted[index].onsetTicks
            var chord: [RawMIDINote] = []
            while index < sorted.count && sorted[index].onsetTicks == onset {
                chord.append(sorted[index])
                index += 1
            }

            if chord.count >= 2 {
                let half = (chord.count + 1) / 2
                for (k, note) in chord.enumerated() {
                    if k < half {
                        voiceA.append(note); lastA = note
                    } else {
                        voiceB.append(note); lastB = note
                    }
                }
                continue
            }

            let note = chord[0]
            let future = lookAheadNotes(after: index, in: sorted, from: note)

            let bias = Double(note.pitch) > average ? -parameters.registerBias
                                                    : parameters.registerBias
            let costA = cost(note, following: lastA, against: lastB, future: future) + bias
            let costB = cost(note, following: lastB, against: lastA, future: future) - bias

            if costA <= costB {
                voiceA.append(note); lastA = note
            } else {
                voiceB.append(note); lastB = note
            }
        }

        return (voiceA, voiceB)
    }

    private func lookAheadNotes(after index: Int,
                                in sorted: [RawMIDINote],
                                from note: RawMIDINote) -> [RawMIDINote] {
        var result: [RawMIDINote] = []
        var k = index
        while k < sorted.count {
            let gap = beats(sorted[k].onsetTicks - note.onsetTicks)
            if gap > parameters.lookAhead { break }
            result.append(sorted[k])
            k += 1
        }
        return result
    }

    // MARK: - Cost

    private func cost(_ note: RawMIDINote,
                      following last: RawMIDINote?,
                      against other: RawMIDINote?,
                      future: [RawMIDINote]) -> Double {
        var total = 0.0

        if let last {
            let interval = abs(note.pitch - last.pitch)
            if interval > parameters.maxComfortableLeap {
                total += Double(interval) * parameters.leapPenalty
            } else {
                total += Double(interval) * parameters.stepPenalty
            }

            let rest = beats(note.onsetTicks - last.endTicks)
            if rest > parameters.maxComfortableRest {
                total += rest.doubleValue * parameters.silencePenalty
            }
        }

        if let other, let last {
            let wasAbove = last.pitch > other.pitch
            let isAbove = note.pitch > other.pitch
            if wasAbove != isAbove {
                total += parameters.crossingPenalty
            }
            if wasAbove && note.pitch < other.pitch - 12 {
                total += parameters.extremeCrossingPenalty
            } else if !wasAbove && note.pitch > other.pitch + 12 {
                total += parameters.extremeCrossingPenalty
            }
        }

        if !future.isEmpty {
            let target = averagePitch(future)
            total += abs(Double(note.pitch) - target) * parameters.lookAheadWeight
        }

        return total
    }

    // MARK: - Helpers

    private func averagePitch(_ notes: [RawMIDINote]) -> Double {
        guard !notes.isEmpty else { return 60.0 }
        return Double(notes.reduce(0) { $0 + $1.pitch }) / Double(notes.count)
    }

    private func orderByRegister(_ a: [RawMIDINote],
                                 _ b: [RawMIDINote]) -> ([RawMIDINote], [RawMIDINote]) {
        let sortA = a.sorted { $0.onsetTicks < $1.onsetTicks }
        let sortB = b.sorted { $0.onsetTicks < $1.onsetTicks }
        if sortA.isEmpty { return (sortB, sortA) }
        if sortB.isEmpty { return (sortA, sortB) }
        return averagePitch(sortA) >= averagePitch(sortB) ? (sortA, sortB) : (sortB, sortA)
    }
}
