//
//  Scores.swift
//  MotifEngine
//
//  Hand-encoded public-domain openings, for use as fixtures and as material for the app.
//
//  Why these are typed in rather than imported: MIDI is not always available, and when it is it
//  carries a performance rather than a text. The Beethoven file in Downloads is an orchestral
//  reduction that doubles every line across a dozen channels, which is excellent for exercising
//  voice separation and useless as a clean motif. A score encoded by hand gives the other thing —
//  one note per note, exactly as written.
//
//  PROVENANCE AND CONFIDENCE. This matters more than usual, because a wrong note here is invisible
//  downstream: the algebra will happily analyse it and report similarity classes about music
//  Beethoven did not write.
//
//    * `fifthSymphonyMotto` is transcribed from the parsed MIDI file, cross-checked against the
//      printed arrangement. The MIDI is the stronger source and it agrees with the page.
//    * `furElise` is encoded by hand from the printed page (3/8, Poco moto, A minor) and from the
//      standard text of the piece. It covers the opening phrase and its repeat — bars 1–8 plus the
//      two-sixteenth upbeat — and nothing after that.
//
//  Everything here is checkable by ear: play it. `ScoresTests` also asserts the sounding pitch
//  sequences note by note, so a wrong note fails a test rather than quietly becoming data.
//
//  Time is measured in quarter notes, as everywhere in the algebra. In 3/8 that makes a bar
//  three eighths — 3/2 quarters — and a sixteenth 1/4. Nothing here needs a denominator the
//  algebra cannot hold exactly.
//

import Foundation
import MotifAlgebra

public enum Scores {

    /// A note-entry cursor. Keeps the running position so bars can be written as sequences of
    /// durations, the way they are read off a page, instead of as computed onsets.
    private struct Pen {
        let space: Space
        let voice: Int
        var cursor: Rational = .zero
        var notes: [Note] = []

        static let sixteenth = Rational(1, 4)

        mutating func play(_ midi: Int, _ sixteenths: Int, velocity: Int = 64) {
            let duration = Pen.sixteenth * Rational(sixteenths)
            notes.append(Note(onset: cursor,
                              duration: duration,
                              pitch: Pitch(importingMIDI: midi, in: space),
                              velocity: velocity,
                              voice: voice))
            cursor = cursor + duration
        }

        mutating func rest(_ sixteenths: Int) {
            cursor = cursor + Pen.sixteenth * Rational(sixteenths)
        }

        /// Assert the cursor is where the bar line says it should be. Catches a miscounted bar at
        /// the point of entry rather than as a puzzling result later.
        mutating func barline(_ bar: Int) {
            let expected = Rational(3, 2) * Rational(bar)
            precondition(cursor == expected + Pen.sixteenth * Rational(2),
                         "bar \(bar) ends at \(cursor), expected \(expected + Pen.sixteenth * Rational(2))")
        }
    }

    // MARK: - Für Elise

    /// A minor with the raised seventh, so G-sharp is a scale degree rather than an accidental.
    /// D-sharp stays chromatic, which is what it is — a neighbour to E, not a member of the key.
    public static let furEliseSpace = Space(tonicPitchClass: 9,
                                           pattern: Space.harmonicMinorPattern,
                                           name: "A minor")

    /// Für Elise, WoO 59 — the opening phrase and its repeat. Bars 1–8 plus the upbeat.
    ///
    /// Voice 0 is the right hand, voice 1 the left. The left hand is silent through the upbeat
    /// and first bar, which is why the piece opens as a bare line.
    public static var furElise: Phrase {
        let space = furEliseSpace

        // Right hand.
        var rh = Pen(space: space, voice: 0)

        // Upbeat: two sixteenths.
        rh.play(76, 1)                      // E5
        rh.play(75, 1)                      // D#5

        func openingRun(into pen: inout Pen) {
            pen.play(76, 1)                 // E5
            pen.play(75, 1)                 // D#5
            pen.play(76, 1)                 // E5
            pen.play(71, 1)                 // B4
            pen.play(74, 1)                 // D5
            pen.play(72, 1)                 // C5
        }

        func firstAnswer(into pen: inout Pen) {
            pen.play(69, 2)                 // A4, an eighth
            pen.rest(1)
            pen.play(60, 1)                 // C4
            pen.play(64, 1)                 // E4
            pen.play(69, 1)                 // A4
        }

        func secondAnswer(into pen: inout Pen) {
            pen.play(71, 2)                 // B4, an eighth
            pen.rest(1)
            pen.play(64, 1)                 // E4
            pen.play(68, 1)                 // G#4
            pen.play(71, 1)                 // B4
        }

        func turnBack(into pen: inout Pen) {
            pen.play(72, 2)                 // C5, an eighth
            pen.rest(1)
            pen.play(64, 1)                 // E4
            pen.play(76, 1)                 // E5
            pen.play(75, 1)                 // D#5
        }

        openingRun(into: &rh);   rh.barline(1)
        firstAnswer(into: &rh);  rh.barline(2)
        secondAnswer(into: &rh); rh.barline(3)
        turnBack(into: &rh);     rh.barline(4)

        // The repeat. Bar 8 closes on A instead of turning back again.
        openingRun(into: &rh);   rh.barline(5)
        firstAnswer(into: &rh);  rh.barline(6)
        secondAnswer(into: &rh); rh.barline(7)
        rh.play(72, 2)                      // C5
        rh.rest(1)
        rh.play(64, 1)                      // E4
        rh.play(69, 2)                      // A4 — the close
        rh.barline(8)

        // Left hand: broken triads, one to a bar, entering at bar 2.
        var lh = Pen(space: space, voice: 1)
        lh.rest(2)                          // upbeat
        lh.rest(6)                          // bar 1 — silent

        func aMinorTriad(into pen: inout Pen) {
            pen.play(45, 2)                 // A2
            pen.play(52, 2)                 // E3
            pen.play(57, 2)                 // A3
        }

        func eMajorTriad(into pen: inout Pen) {
            pen.play(40, 2)                 // E2
            pen.play(52, 2)                 // E3
            pen.play(56, 2)                 // G#3
        }

        func aMinorOpen(into pen: inout Pen) {
            pen.play(45, 2)                 // A2
            pen.play(52, 2)                 // E3
            pen.rest(2)
        }

        aMinorTriad(into: &lh); lh.barline(2)
        eMajorTriad(into: &lh); lh.barline(3)
        aMinorOpen(into: &lh);  lh.barline(4)

        lh.rest(6)                          // bar 5 — silent again under the run
        aMinorTriad(into: &lh); lh.barline(6)
        eMajorTriad(into: &lh); lh.barline(7)
        aMinorOpen(into: &lh);  lh.barline(8)

        return Phrase(rh.notes + lh.notes, in: space)
    }

    /// The right hand alone — a monophonic line, which is what the similarity classes are
    /// defined on and what the greedy voice separator has had no real music to chew on.
    public static var furEliseMelody: Phrase {
        Phrase(furElise.notes.filter { $0.voice == 0 }, in: furEliseSpace)
    }

    // MARK: - Symphony No. 5

    /// C minor. The Fifth's first movement is in C minor with a B-natural leading tone.
    public static let fifthSpace = Space(tonicPitchClass: 0,
                                         pattern: Space.harmonicMinorPattern,
                                         name: "C minor")

    /// The motto and its answer — the first four bars of Op. 67.
    ///
    /// Three short notes and a long one, then the same shape a step lower. Transcribed from the
    /// MIDI file, which gives the three repeated notes as very short values with a rest before the
    /// held note; that is the performance. Written as the page has it: three eighths and a fermata
    /// half, which is the text.
    ///
    /// This is the cleanest possible test of the algebra's central claim, and it is worth stating
    /// carefully because the obvious reading is the wrong one.
    ///
    /// In C minor the degrees are C D E-flat F G A-flat B. The motto falls G → E-flat, which is
    /// two scale steps down. The answer falls F → D, which is also two scale steps down. So the
    /// answer is an exact diatonic transposition of the motto by minus one step — `translate(-1)`
    /// reproduces it note for note.
    ///
    /// Count in semitones instead and the relationship disappears: G → E-flat is three semitones,
    /// F → D is two. A matcher working on semitone intervals sees two different shapes and has to
    /// fall back on something fuzzy to relate them. A matcher working on the scale lattice sees
    /// one transposition and an exact one, which is why `Pitch` stores a spelled step rather than
    /// deriving itself from a MIDI number.
    ///
    /// `ScoresTests` asserts the transposition rather than describing it.
    public static var fifthSymphonyMotto: Phrase {
        var pen = Pen(space: fifthSpace, voice: 0)

        // Bars 1–2: rest, then G G G, then E-flat held.
        pen.rest(2)
        pen.play(67, 2, velocity: 100)      // G4
        pen.play(67, 2, velocity: 100)      // G4
        pen.play(67, 2, velocity: 100)      // G4
        pen.play(63, 8, velocity: 100)      // Eb4, held

        // Bars 3–4: the answer, a third lower in the scale.
        pen.rest(2)
        pen.play(65, 2, velocity: 100)      // F4
        pen.play(65, 2, velocity: 100)      // F4
        pen.play(65, 2, velocity: 100)      // F4
        pen.play(62, 8, velocity: 100)      // D4, held

        return Phrase(pen.notes, in: fifthSpace)
    }

    /// The motto alone, without its answer — the four-note cell everything in the movement is
    /// built from.
    public static var fifthSymphonyCell: Phrase {
        Phrase(Array(fifthSymphonyMotto.notes.prefix(4)), in: fifthSpace)
            .normalizedToZero()
    }
}
