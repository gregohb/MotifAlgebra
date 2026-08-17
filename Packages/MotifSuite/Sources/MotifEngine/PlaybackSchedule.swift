//
//  PlaybackSchedule.swift
//  MotifEngine
//
//  What to play and exactly when, computed before a single sample is produced.
//
//  This file exists because AMT005 had no such thing, and that was the root of its timing
//  problems. Its player ran a loop that compared each note's onset against a `playbackPosition`
//  variable, and that variable was advanced by a separate repeating Timer:
//
//      let newPosition = self.playbackPosition + (0.05 * beatsPerSecond)   // every 0.05s
//
//  So the position was an accumulator fed by a timer that fires *approximately* every 50 ms.
//  Two things follow, and both were audible:
//
//    * Drift. Timer is not a clock. Every late firing adds its lateness permanently to the
//      accumulator, because the increment is a constant regardless of how long actually
//      elapsed. Under any load the piece slows down, and never catches up.
//    * Jitter. The playback loop slept in 100 ms slices — `Thread.sleep(min(wait, 0.1))` — and
//      only checked between slices, so a note could fire up to 100 ms late even with a perfect
//      position. At allegro a dotted eighth lasts 173 ms. The error was within a factor of two
//      of the note value.
//
//  The fix is to stop accumulating. Every event's time is computed independently from the start
//  of playback — `onset × secondsPerBeat`, once, from the phrase's exact Rational onset — so
//  there is no running total for error to collect in. Playback then becomes: take a single start
//  instant, and fire each event at `start + offset`. Lateness on one note cannot affect the next,
//  because the next note's deadline was never derived from it.
//
//  Computing this ahead of time also makes the timing testable without a sound card, which is
//  the other reason it is a separate type. Everything below is pure arithmetic.
//

import Foundation
import MotifAlgebra

public struct PlaybackSchedule: Sendable {

    // MARK: - Event

    public struct Event: Hashable, Sendable {

        /// Sounding pitch. Spelling is irrelevant to a synthesiser, so this is resolved here.
        public var midi: Int
        public var velocity: Int
        public var channel: Int
        public var voice: Int

        /// Exact musical position, kept for display and for tests.
        public var onsetBeats: Rational
        public var durationBeats: Rational

        /// Clock time relative to the start of playback.
        public var onsetSeconds: Double
        public var durationSeconds: Double

        public var endSeconds: Double { onsetSeconds + durationSeconds }
    }

    // MARK: - Voice selection

    /// Replaces AMT005's `VoiceDisplayMode`, which hard-coded exactly two voices as
    /// `.voice1Only` / `.voice2Only`. Overlay and zip can produce more than two.
    public enum VoiceFilter: Hashable, Sendable {
        case all
        case only(Int)
        case except(Int)

        func admits(_ voice: Int) -> Bool {
            switch self {
            case .all: return true
            case let .only(v): return voice == v
            case let .except(v): return voice != v
            }
        }
    }

    // MARK: - Stored

    public private(set) var events: [Event]
    public let tempo: Tempo
    public let startBeat: Rational

    /// Musical length, exactly.
    public let totalBeats: Rational

    /// Clock length. Derived from `totalBeats` in one multiplication — not summed over events.
    public var totalSeconds: Double { tempo.seconds(totalBeats) }

    public var isEmpty: Bool { events.isEmpty }

    // MARK: - Construction

    public init(phrase: Phrase,
                tempo: Tempo,
                from startBeat: Rational = .zero,
                voices: VoiceFilter = .all) {
        self.tempo = tempo
        self.startBeat = startBeat

        let space = phrase.space

        let selected = phrase.notes.filter { note in
            voices.admits(note.voice) && note.end > startBeat
        }

        self.events = selected.map { note in
            // Each offset computed from the note's own onset. No accumulator anywhere.
            let onset = note.onset - startBeat
            let clippedOnset = onset < .zero ? Rational.zero : onset
            let duration = onset < .zero ? note.end - startBeat : note.duration

            return Event(midi: note.midi(in: space),
                         velocity: note.velocity,
                         channel: max(0, min(15, note.voice)),
                         voice: note.voice,
                         onsetBeats: clippedOnset,
                         durationBeats: duration,
                         onsetSeconds: tempo.seconds(clippedOnset),
                         durationSeconds: tempo.seconds(duration))
        }
        .sorted {
            if $0.onsetBeats != $1.onsetBeats { return $0.onsetBeats < $1.onsetBeats }
            return $0.midi < $1.midi
        }

        let end = selected.map(\.end).max() ?? startBeat
        self.totalBeats = end > startBeat ? end - startBeat : .zero
    }

    /// A schedule for several phrases at once — the voices of an import, or a motif beside its
    /// transformation. Voice numbers are taken from the phrases themselves.
    public init(phrases: [Phrase],
                tempo: Tempo,
                from startBeat: Rational = .zero,
                voices: VoiceFilter = .all) {
        let merged = Phrase(phrases.flatMap(\.notes),
                            in: phrases.first?.space ?? .cMajor)
        self.init(phrase: merged, tempo: tempo, from: startBeat, voices: voices)
    }

    // MARK: - Requerying

    /// The same music at a different tempo. Recomputed from the rational onsets rather than by
    /// rescaling the seconds, so repeated tempo changes cannot compound rounding.
    public func at(tempo newTempo: Tempo) -> PlaybackSchedule {
        var copy = self
        copy.events = events.map { event in
            var e = event
            e.onsetSeconds = newTempo.seconds(event.onsetBeats)
            e.durationSeconds = newTempo.seconds(event.durationBeats)
            return e
        }
        return PlaybackSchedule(events: copy.events,
                                tempo: newTempo,
                                startBeat: startBeat,
                                totalBeats: totalBeats)
    }

    private init(events: [Event], tempo: Tempo, startBeat: Rational, totalBeats: Rational) {
        self.events = events
        self.tempo = tempo
        self.startBeat = startBeat
        self.totalBeats = totalBeats
    }

    /// Musical position at a given elapsed clock time. Used for the playhead, and derived from
    /// the clock rather than accumulated alongside it.
    public func beatPosition(atElapsed seconds: Double) -> Double {
        startBeat.doubleValue + tempo.beats(seconds: seconds)
    }

    /// Events falling in a half-open window, for callers that want to hand work to an audio
    /// callback in slices.
    public func events(from: Double, until: Double) -> [Event] {
        events.filter { $0.onsetSeconds >= from && $0.onsetSeconds < until }
    }
}
