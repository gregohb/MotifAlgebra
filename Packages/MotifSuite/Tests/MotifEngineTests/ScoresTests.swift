//
//  ScoresTests.swift
//  MotifEngineTests
//
//  A wrong note in a hand-encoded score is invisible: the algebra analyses it happily and reports
//  similarity classes about music nobody wrote. So the encodings are asserted note by note, in
//  sounding pitch, against the text.
//

import XCTest
@testable import MotifEngine
import MotifAlgebra

final class ScoresTests: XCTestCase {

    // MARK: - Für Elise

    func testFurEliseOpeningRightHand() {
        let melody = Scores.furEliseMelody

        // Upbeat, then bars 1–4.
        let expected = [
            76, 75,                          // upbeat: E5 D#5
            76, 75, 76, 71, 74, 72,          // bar 1
            69, 60, 64, 69,                  // bar 2
            71, 64, 68, 71,                  // bar 3
            72, 64, 76, 75,                  // bar 4
            76, 75, 76, 71, 74, 72,          // bar 5 — the repeat
            69, 60, 64, 69,                  // bar 6
            71, 64, 68, 71,                  // bar 7
            72, 64, 69                       // bar 8 — closes on A
        ]

        XCTAssertEqual(melody.midis, expected)
    }

    func testFurEliseIsThreeEightTime() {
        let phrase = Scores.furElise

        // Upbeat of two sixteenths plus eight bars of three eighths.
        let expected = Rational(1, 2) + Rational(3, 2) * Rational(8)
        XCTAssertEqual(phrase.end, expected)
        XCTAssertEqual(phrase.end, Rational(25, 2))
    }

    /// The left hand is silent until bar 2 — the reason the piece opens as a bare line.
    func testFurEliseLeftHandEntersAtBarTwo() {
        let left = Scores.furElise.notes.filter { $0.voice == 1 }
        let firstOnset = left.map(\.onset).min()

        // Bar 2 begins after the upbeat plus one bar: 1/2 + 3/2 = 2.
        XCTAssertEqual(firstOnset, Rational(2))
        XCTAssertEqual(left.first(where: { $0.onset == Rational(2) })?.midi(in: Scores.furEliseSpace),
                       45, "the left hand enters on A2")
    }

    func testFurEliseBothHandsPresent() {
        let phrase = Scores.furElise
        XCTAssertEqual(Set(phrase.notes.map(\.voice)), [0, 1])
        XCTAssertEqual(phrase.notes.filter { $0.voice == 0 }.count, 37)
        XCTAssertEqual(phrase.notes.filter { $0.voice == 1 }.count, 16)
    }

    /// G-sharp is a scale degree in this space, not an accidental; D-sharp is genuinely chromatic.
    /// If that were the other way round, diatonic transposition of the theme would misbehave.
    func testFurEliseSpelling() {
        let space = Scores.furEliseSpace
        let gSharp = Pitch(importingMIDI: 68, in: space)
        let dSharp = Pitch(importingMIDI: 75, in: space)

        XCTAssertTrue(gSharp.isDiatonic, "G# is the raised seventh of A minor")
        XCTAssertFalse(dSharp.isDiatonic, "D# is a chromatic neighbour to E")
    }

    /// The opening run alternates E and D-sharp: a semitone oscillation, so the step-interval
    /// vector must open with a zero pair rather than a unison.
    func testFurEliseOpeningIsNotAUnison() {
        let melody = Scores.furEliseMelody
        let firstTwo = Phrase(Array(melody.notes.prefix(2)), in: Scores.furEliseSpace)

        XCTAssertEqual(firstTwo.midis, [76, 75], "E5 then D#5 — different sounding pitches")
        XCTAssertNotEqual(firstTwo.notes[0].pitch, firstTwo.notes[1].pitch)
    }

    // MARK: - Symphony No. 5

    func testFifthMottoAndAnswer() {
        let phrase = Scores.fifthSymphonyMotto
        XCTAssertEqual(phrase.midis, [67, 67, 67, 63, 65, 65, 65, 62],
                       "G G G Eb, then F F F D")
    }

    /// The claim the whole spelled-pitch design exists to support.
    ///
    /// The answer is the motto transposed down exactly one scale step. In semitones the two
    /// figures are different shapes — G to E-flat is three semitones, F to D is two — so a
    /// semitone-based matcher cannot relate them by a single transposition. On the scale lattice
    /// it is `translate(-1)`, exactly, note for note.
    func testFifthAnswerIsTheMottoTransposedDownOneStep() {
        let notes = Scores.fifthSymphonyMotto.notes
        let motto = Phrase(Array(notes.prefix(4)), in: Scores.fifthSpace).normalizedToZero()
        let answer = Phrase(Array(notes.suffix(4)), in: Scores.fifthSpace).normalizedToZero()

        let transposed = Transform.translate(-1).apply(to: motto)

        XCTAssertEqual(transposed.midis, answer.midis,
                       "translate(-1) must reproduce the answer exactly")
        XCTAssertEqual(transposed.notes.map(\.pitch), answer.notes.map(\.pitch),
                       "and with the same spelling, not merely the same sound")
    }

    /// The semitone reading, stated so the contrast is on record rather than merely asserted in
    /// a comment.
    func testTheSameRelationIsInvisibleInSemitones() {
        let notes = Scores.fifthSymphonyMotto.notes
        let space = Scores.fifthSpace

        let mottoFall = notes[3].midi(in: space) - notes[2].midi(in: space)     // Eb - G
        let answerFall = notes[7].midi(in: space) - notes[6].midi(in: space)    // D - F

        XCTAssertEqual(mottoFall, -4)
        XCTAssertEqual(answerFall, -3)
        XCTAssertNotEqual(mottoFall, answerFall,
                          "in semitones the two figures are different intervals")

        // On the lattice they are the same interval.
        XCTAssertEqual(Scores.fifthSymphonyMotto.stepIntervals.prefix(3).map { $0 },
                       [0, 0, -2])
    }

    /// Same contour, so the strictest similarity classes should recognise it.
    func testMottoAndAnswerAreCongruent() {
        let notes = Scores.fifthSymphonyMotto.notes
        let motto = Phrase(Array(notes.prefix(4)), in: Scores.fifthSpace)
        let answer = Phrase(Array(notes.suffix(4)), in: Scores.fifthSpace)

        XCTAssertEqual(Similarity.classify(reference: motto, candidate: answer), .congruent,
                       "identical interval vectors")
    }

    func testFifthCellIsFourNotesFromZero() {
        let cell = Scores.fifthSymphonyCell
        XCTAssertEqual(cell.count, 4)
        XCTAssertEqual(cell.start, .zero)
        XCTAssertEqual(cell.midis, [67, 67, 67, 63])
    }

    // MARK: - Both are playable

    func testBothScoresSchedule() {
        for phrase in [Scores.furElise, Scores.fifthSymphonyMotto] {
            let schedule = PlaybackSchedule(phrase: phrase, tempo: Tempo(bpm: 72))
            XCTAssertEqual(schedule.events.count, phrase.count)
            XCTAssertGreaterThan(schedule.totalSeconds, 0)
            XCTAssertTrue(schedule.events.allSatisfy { $0.midi > 0 && $0.midi < 128 },
                          "every note must be playable on a keyboard")
        }
    }
}
