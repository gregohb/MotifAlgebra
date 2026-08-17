//
//  PlaybackScheduleTests.swift
//  MotifEngineTests
//
//  The timing tests. These are the reason the schedule is a separate, pure type: everything that
//  determines when a note sounds can be checked here, with no audio hardware and no waiting in
//  real time.
//

import XCTest
@testable import MotifEngine
import MotifAlgebra

final class PlaybackScheduleTests: XCTestCase {

    // MARK: - Tempo

    func testTempoIsClampedToPlayableRange() {
        XCTAssertEqual(Tempo(bpm: 5).bpm, Tempo.minimumBPM)
        XCTAssertEqual(Tempo(bpm: 5000).bpm, Tempo.maximumBPM)
        XCTAssertEqual(Tempo(bpm: .nan).bpm, 120)
        XCTAssertEqual(Tempo(bpm: .infinity).bpm, Tempo.maximumBPM)
    }

    func testTempoConversionsAreInverse() {
        let tempo = Tempo(bpm: 96)
        let beats = Rational(7, 2)
        let seconds = tempo.seconds(beats)
        XCTAssertEqual(tempo.beats(seconds: seconds), beats.doubleValue, accuracy: 1e-12)
    }

    func testTempoMarkingsMapBothWays() {
        XCTAssertEqual(Tempo(.allegro).bpm, 130)
        XCTAssertEqual(Tempo(bpm: 130).closestMarking, .allegro)
        XCTAssertEqual(Tempo(bpm: 131).closestMarking, .allegro)
        XCTAssertTrue(Tempo(bpm: 130).description.contains("Allegro"))
    }

    // MARK: - Note values

    /// AMT005 wrote the triplets as `1.0 / 3.0`. Three of them summed to 0.99999999999999989,
    /// so a bar of triplets did not close.
    func testTripletNoteValuesAreExact() {
        let third = NoteValue.tripletEighth.beats
        XCTAssertEqual(third, Rational(1, 3))
        XCTAssertEqual(third + third + third, Rational(1))

        XCTAssertEqual(NoteValue.tripletQuarter.beats + NoteValue.tripletEighth.beats, Rational(1))
        XCTAssertEqual(NoteValue.tripletWhole.beats, Rational(8, 3))
    }

    func testDottedValuesAreExact() {
        XCTAssertEqual(NoteValue.dottedQuarter.beats, Rational(3, 2))
        XCTAssertEqual(NoteValue.dottedEighth.beats + NoteValue.sixteenth.beats, Rational(1))
        XCTAssertEqual(NoteValue.matching(Rational(3, 4)), .dottedEighth)
        XCTAssertNil(NoteValue.matching(Rational(5, 7)))
    }

    // MARK: - No accumulation

    /// The headline property. Onsets are computed independently, so the thousandth event is as
    /// accurate as the first.
    ///
    /// AMT005's position advanced by `+= 0.05 * beatsPerSecond` on a timer, so its error grew
    /// without bound. The comparison below is against the exact rational answer.
    func testLongRunOfTripletsDoesNotDrift() {
        let tempo = Tempo(bpm: 120)
        let count = 1000
        let third = Rational(1, 3)

        var notes: [Note] = []
        for i in 0 ..< count {
            notes.append(Note(third * Rational(i), third, i % 7))
        }
        let schedule = PlaybackSchedule(phrase: Phrase(notes, in: .cMajor), tempo: tempo)

        XCTAssertEqual(schedule.events.count, count)

        // Exact expected time of the final onset: 999/3 beats = 333 beats = 166.5 s at 120 BPM.
        let last = try! XCTUnwrap(schedule.events.last)
        XCTAssertEqual(last.onsetBeats, Rational(999, 3))
        XCTAssertEqual(last.onsetSeconds, 166.5, accuracy: 1e-9)

        // Every event agrees with the closed form, not just the last.
        for (i, event) in schedule.events.enumerated() {
            let expected = (Double(i) / 3.0) * tempo.secondsPerBeat
            XCTAssertEqual(event.onsetSeconds, expected, accuracy: 1e-9,
                           "event \(i) has drifted")
        }
    }

    /// A running total of the same values, which is what the old design effectively kept, is
    /// measurably wrong by the end. This test documents the size of the error being avoided.
    func testAccumulationWouldHaveDrifted() {
        let increment = 1.0 / 3.0
        var accumulated = 0.0
        for _ in 0 ..< 1000 { accumulated += increment }

        let exact = Rational(1000, 3).doubleValue

        XCTAssertNotEqual(accumulated, exact)
        XCTAssertGreaterThan(abs(accumulated - exact), 1e-14)
    }

    func testTotalLengthIsExactNotSummed() {
        let phrase = Phrase([
            Note(Rational(0), Rational(1, 3), 0),
            Note(Rational(1, 3), Rational(1, 3), 1),
            Note(Rational(2, 3), Rational(1, 3), 2)
        ], in: .cMajor)

        let schedule = PlaybackSchedule(phrase: phrase, tempo: Tempo(bpm: 60))
        XCTAssertEqual(schedule.totalBeats, Rational(1))
        XCTAssertEqual(schedule.totalSeconds, 1.0, accuracy: 1e-12)
    }

    // MARK: - Content

    /// A C major scale from middle C. Step 35 is middle C: the lattice is absolute and
    /// zero-based, so seven steps to the octave puts step 0 at C-1, MIDI 0.
    private var scale: Phrase {
        Phrase((0 ..< 8).map { Note(Rational($0), Rational(1), 35 + $0) }, in: .cMajor)
    }

    func testEventsCarrySoundingPitch() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo())
        XCTAssertEqual(schedule.events.map(\.midi), [60, 62, 64, 65, 67, 69, 71, 72])
    }

    func testEventsAreOrderedByOnset() {
        let shuffled = Phrase([
            Note(Rational(3), Rational(1), 4),
            Note(Rational(0), Rational(1), 0),
            Note(Rational(2), Rational(1), 2)
        ], in: .cMajor)

        let schedule = PlaybackSchedule(phrase: shuffled, tempo: Tempo())
        XCTAssertEqual(schedule.events.map(\.onsetBeats),
                       [Rational(0), Rational(2), Rational(3)])
    }

    func testTempoChangeScalesEverythingProportionally() {
        let slow = PlaybackSchedule(phrase: scale, tempo: Tempo(bpm: 60))
        let fast = slow.at(tempo: Tempo(bpm: 120))

        XCTAssertEqual(fast.events.count, slow.events.count)
        XCTAssertEqual(fast.totalSeconds, slow.totalSeconds / 2, accuracy: 1e-12)

        for (s, f) in zip(slow.events, fast.events) {
            XCTAssertEqual(f.onsetSeconds, s.onsetSeconds / 2, accuracy: 1e-12)
            XCTAssertEqual(f.onsetBeats, s.onsetBeats, "musical time must not change")
        }
    }

    /// Repeated tempo changes recompute from the rational onsets, so they cannot compound.
    func testRepeatedTempoChangesDoNotCompoundError() {
        var schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(bpm: 120))
        let original = schedule.events.map(\.onsetSeconds)

        for _ in 0 ..< 50 {
            schedule = schedule.at(tempo: Tempo(bpm: 61))
            schedule = schedule.at(tempo: Tempo(bpm: 120))
        }

        for (a, b) in zip(original, schedule.events.map(\.onsetSeconds)) {
            XCTAssertEqual(a, b, accuracy: 1e-12)
        }
    }

    // MARK: - Voice filtering

    func testVoiceFilterSelectsVoices() {
        let upper = Phrase((0 ..< 4).map { Note(Rational($0), Rational(1), 7 + $0) },
                           in: .cMajor).withVoice(0)
        let lower = Phrase((0 ..< 4).map { Note(Rational($0), Rational(1), $0) },
                           in: .cMajor).withVoice(1)
        let both = Phrase(upper.notes + lower.notes, in: .cMajor)

        XCTAssertEqual(PlaybackSchedule(phrase: both, tempo: Tempo()).events.count, 8)
        XCTAssertEqual(PlaybackSchedule(phrase: both, tempo: Tempo(), voices: .only(0)).events.count, 4)
        XCTAssertEqual(PlaybackSchedule(phrase: both, tempo: Tempo(), voices: .except(0)).events.count, 4)
    }

    /// AMT005's VoiceDisplayMode had exactly three cases and could not express a third voice,
    /// though overlay and zip both produce one.
    func testFilterHandlesMoreThanTwoVoices() {
        var notes: [Note] = []
        for voice in 0 ..< 4 {
            notes.append(Note(onset: Rational(voice), duration: Rational(1),
                              pitch: Pitch(step: voice), velocity: 80, voice: voice))
        }
        let phrase = Phrase(notes, in: .cMajor)

        XCTAssertEqual(PlaybackSchedule(phrase: phrase, tempo: Tempo(), voices: .only(3)).events.count, 1)
        XCTAssertEqual(PlaybackSchedule(phrase: phrase, tempo: Tempo(), voices: .except(3)).events.count, 3)
    }

    // MARK: - Starting part-way in

    func testStartingPartWayInDropsEarlierNotes() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(), from: Rational(4))

        XCTAssertEqual(schedule.events.count, 4)
        XCTAssertEqual(schedule.events.first?.onsetBeats, Rational(0))
        XCTAssertEqual(schedule.events.first?.midi, 67)
    }

    /// A note still sounding at the resume point is kept, shortened to its remainder. Dropping it
    /// leaves a hole in any held line.
    func testNoteSoundingAtStartPointIsKeptAndShortened() {
        let held = Phrase([Note(Rational(0), Rational(8), 0)], in: .cMajor)
        let schedule = PlaybackSchedule(phrase: held, tempo: Tempo(bpm: 60), from: Rational(3))

        XCTAssertEqual(schedule.events.count, 1)
        let event = schedule.events[0]
        XCTAssertEqual(event.onsetBeats, Rational(0), "it should sound immediately")
        XCTAssertEqual(event.durationBeats, Rational(5), "with five beats left to run")
        XCTAssertEqual(event.durationSeconds, 5.0, accuracy: 1e-12)
    }

    func testStartingBeyondTheEndYieldsNothing() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(), from: Rational(100))
        XCTAssertTrue(schedule.isEmpty)
        XCTAssertEqual(schedule.totalBeats, .zero)
    }

    // MARK: - Playhead

    func testBeatPositionIsDerivedFromElapsedTime() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(bpm: 120))

        XCTAssertEqual(schedule.beatPosition(atElapsed: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(schedule.beatPosition(atElapsed: 0.5), 1, accuracy: 1e-12)
        XCTAssertEqual(schedule.beatPosition(atElapsed: 2.0), 4, accuracy: 1e-12)
    }

    func testBeatPositionRespectsStartOffset() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(bpm: 120), from: Rational(4))
        XCTAssertEqual(schedule.beatPosition(atElapsed: 0), 4, accuracy: 1e-12)
        XCTAssertEqual(schedule.beatPosition(atElapsed: 1.0), 6, accuracy: 1e-12)
    }

    // MARK: - Windowing

    func testWindowQueryIsHalfOpen() {
        let schedule = PlaybackSchedule(phrase: scale, tempo: Tempo(bpm: 60))
        let window = schedule.events(from: 1.0, until: 3.0)

        XCTAssertEqual(window.map(\.onsetSeconds), [1.0, 2.0])
    }

    // MARK: - Degenerate input

    func testEmptyPhraseProducesEmptySchedule() {
        let schedule = PlaybackSchedule(phrase: Phrase([], in: .cMajor), tempo: Tempo())
        XCTAssertTrue(schedule.isEmpty)
        XCTAssertEqual(schedule.totalSeconds, 0)
    }

    func testMergingPhrasesKeepsEveryNote() {
        let a = Phrase([Note(Rational(0), Rational(1), 0)], in: .cMajor).withVoice(0)
        let b = Phrase([Note(Rational(0), Rational(1), 4)], in: .cMajor).withVoice(1)

        let schedule = PlaybackSchedule(phrases: [a, b], tempo: Tempo())
        XCTAssertEqual(schedule.events.count, 2)
        XCTAssertEqual(Set(schedule.events.map(\.voice)), [0, 1])
    }
}
