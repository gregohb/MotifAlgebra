//
//  AlgebraLawTests.swift
//  MotifAlgebraTests
//
//  Executable statements of the algebra's laws.
//
//  These are not decoration. The reason for exact rationals, spelled pitch and typed parameters
//  is precisely that claims like `retrograde ∘ retrograde == identity` become checkable with
//  `==` rather than with a tolerance. If any of these fail, every bit-count downstream is
//  meaningless.
//
//  Every test here passed first in a Python mirror of the same arithmetic (32/32) before being
//  transliterated, because no Swift toolchain was reachable from the environment they were
//  written in. Two of them — the ones marked BUG — encode defects the mirror actually caught in
//  the previous design.
//

import XCTest
@testable import MotifAlgebra

final class AlgebraLawTests: XCTestCase {

    // C4 D4 E4, quarter notes. In C major these are steps 35, 36, 37.
    let cde = Phrase([
        Note(Rational(0), Rational(1), 35),
        Note(Rational(1), Rational(1), 36),
        Note(Rational(2), Rational(1), 37)
    ], in: .cMajor)

    /// Every spelled pitch over a wide range, altered and unaltered alike. The old design passed
    /// its tests only because they used in-scale notes exclusively.
    var allSpelledPitches: [Pitch] {
        (20 ..< 60).flatMap { step in
            (-2 ... 2).map { Pitch(step: step, alteration: $0) }
        }
    }

    // MARK: - Group laws

    func testRetrogradeIsAnInvolution() {
        XCTAssertEqual(Transform.retrograde.then(.retrograde).apply(to: cde), cde)
    }

    func testAugmentThenDiminishIsIdentity() {
        let t = Transform.augment(Rational(2)).then(.diminish(Rational(2)))
        XCTAssertEqual(t.apply(to: cde), cde)
    }

    func testTranslationIsInvertible() {
        XCTAssertEqual(Transform.translate(7).then(.translate(-7)).apply(to: cde), cde)
    }

    func testInversionIsAnInvolutionOnDiatonicMaterial() {
        let inv = Transform.invert(about: 35)
        XCTAssertEqual(inv.then(inv).apply(to: cde), cde)
    }

    func testDiatonicTranspositionStaysInKey() {
        // Up two scale steps from C-D-E gives E-F-G. The scale absorbs the rounding exactly;
        // this is the tonal answer of fugue, and it is why scale-degree space matters.
        XCTAssertEqual(Transform.translate(2).apply(to: cde).midis, [64, 65, 67])
    }

    func testPitchScaleDoublesStepIntervals() {
        XCTAssertEqual(Transform.pitchScale(Rational(2), anchor: 35).apply(to: cde).steps,
                       [35, 37, 39])
    }

    func testNonUnitPitchScaleIsNotInvertible() {
        XCTAssertFalse(Transform.pitchScale(Rational(1, 2), anchor: 35).isInvertible)
    }

    // MARK: - BUG 1: spelled pitch

    func testBug1_DiatonicTranspositionIsInvertibleOnEverySpelledPitch() {
        let f = PitchMap.translate(steps: 2)
        let g = PitchMap.translate(steps: -2)
        let failures = allSpelledPitches.filter { g.apply(to: f.apply(to: $0)) != $0 }
        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count) pitches failed to round-trip: \(failures.prefix(5))")
    }

    func testBug1_InversionIsAnInvolutionOnEverySpelledPitch() {
        let m = PitchMap.invert(about: 35)
        let failures = allSpelledPitches.filter { m.apply(to: m.apply(to: $0)) != $0 }
        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count) pitches failed: \(failures.prefix(5))")
    }

    func testBug1_EnharmonicsAreDistinctButSoundAlike() {
        let cSharp = Pitch(step: 35, alteration: 1)
        let dFlat = Pitch(step: 36, alteration: -1)
        XCTAssertNotEqual(cSharp, dFlat)
        XCTAssertEqual(cSharp.midi(in: .cMajor), 61)
        XCTAssertEqual(dFlat.midi(in: .cMajor), 61)
    }

    func testBug1_InversionSendsAnAscendingSemitoneToADescendingOne() {
        // C-sharp inverted about C must be C-flat, not C-sharp. This is why the alteration
        // scales with the factor rather than riding along unchanged.
        XCTAssertEqual(PitchMap.invert(about: 35).apply(to: Pitch(step: 35, alteration: 1)),
                       Pitch(step: 35, alteration: -1))
    }

    // MARK: - BUG 2: total ordering

    func testBug2_TwoVoiceUnisonOrdersDeterministically() {
        let a = Note(onset: .zero, duration: .one, pitch: Pitch(step: 35), voice: 0)
        let b = Note(onset: .zero, duration: .one, pitch: Pitch(step: 35), voice: 1)
        XCTAssertNotEqual(Note.canonicallyPrecedes(a, b), Note.canonicallyPrecedes(b, a))
        XCTAssertEqual(Phrase([a, b]), Phrase([b, a]))
    }

    // MARK: - The merge of inversion into signed scaling

    func testInversionIsLiterallyScaleByMinusOne() {
        XCTAssertEqual(Transform.invert(about: 35).pitchMaps,
                       Transform.pitchScale(Rational(-1), anchor: 35).pitchMaps)
    }

    func testRetrogradeIsLiterallyTimeScaleByMinusOne() {
        XCTAssertEqual(Transform.retrograde.timeMaps,
                       Transform.timeScale(Rational(-1)).timeMaps)
    }

    func testRetrogradeWithAugmentationIsASingleMap() {
        // The previous four-case design could not express this at all.
        let r = Transform.timeScale(Rational(-2)).apply(to: cde)
        XCTAssertEqual(r.steps, [37, 36, 35])
        XCTAssertEqual(r.notes.map(\.duration), [Rational(2), Rational(2), Rational(2)])
        XCTAssertEqual(Transform.timeScale(Rational(-2))
            .then(.timeScale(Rational(-1, 2))).apply(to: cde), cde)
    }

    // MARK: - Costs

    func testCheapHypothesesCostFewerBitsThanExoticOnes() {
        let cheap = Transform.translate(7).bitCost
        let exotic = Transform.pitchScale(Rational(17, 24), anchor: 35).bitCost
        XCTAssertLessThan(cheap, exotic)
    }

    func testGammaIsExact() {
        for m in 1 ..< 5000 {
            let expected = 2.0 * Double(Int.bitWidth - m.leadingZeroBitCount - 1) + 1.0
            XCTAssertEqual(Cost.gamma(m), expected)
        }
    }

    func testIntegerCostIsSymmetricAboutZero() {
        XCTAssertEqual(Cost.integer(0), 1.0)
        for n in 1 ... 40 {
            XCTAssertEqual(Cost.integer(n), Cost.integer(-n), accuracy: 1e-12,
                           "cost should not depend on the sign of \(n)")
        }
    }

    func testRoundingIsExactAndTiesAwayFromZero() {
        XCTAssertEqual(Rational(1, 2).roundedToInt, 1)
        XCTAssertEqual(Rational(-1, 2).roundedToInt, -1)
        XCTAssertEqual(Rational(3, 2).roundedToInt, 2)
        XCTAssertEqual(Rational(-3, 2).roundedToInt, -2)
        XCTAssertEqual(Rational(0).roundedToInt, 0)
    }

    // MARK: - Similarity classes

    func testSimilarityClassification() {
        let j = [2, -1, 3]
        XCTAssertEqual(Similarity.classify(reference: j, candidate: [2, -1, 3]), .congruent)
        XCTAssertEqual(Similarity.classify(reference: j, candidate: [5, -2, 1]), .strictlySimilar)
        XCTAssertEqual(Similarity.classify(reference: j, candidate: [-5, 2, -1]), .inverselySimilar)
        XCTAssertEqual(Similarity.classify(reference: j, candidate: [2, 0, 3]), .similar)
        XCTAssertEqual(Similarity.classify(reference: j, candidate: [-1, -1, 3]), .unrelated)
    }

    func testAFlatLineIsSimilarToEverything() {
        // The degenerate case. Measured against a shuffled null model this inflated four-note
        // contour coverage to 15.8% on random material — about 70% of short matches were chance.
        XCTAssertEqual(Similarity.classify(reference: [2, -1, 3], candidate: [0, 0, 0]), .similar)
        XCTAssertFalse(Similarity.similar.isFalsifiableOnItsOwn)
        XCTAssertTrue(Similarity.strictlySimilar.isFalsifiableOnItsOwn)
    }

    // MARK: - Reuse: a tree beats a list

    func testCitingASubtreeBeatsWritingTheNotesOut() throws {
        // Subject, then the same subject a diatonic fifth up, stated three times — a fugal answer.
        let program = Program(
            title: "reuse demo",
            space: .cMajor,
            seeds: ["S": cde],
            definitions: [.init(name: "A", body: .apply(.translate(4), .seed("S")))],
            root: .place([
                PlaceItem(at: Rational(0), child: .seed("S")),
                PlaceItem(at: Rational(4), child: .ref("A")),
                PlaceItem(at: Rational(8), child: .ref("A")),
                PlaceItem(at: Rational(12), child: .ref("A"))
            ])
        )
        let produced = try program.evaluate()
        XCTAssertEqual(produced.count, 12)
        XCTAssertTrue(try program.reproducesExactly(produced))
        XCTAssertLessThan(program.bitCost, produced.literalBitCost)
    }

    // MARK: - The fractal string

    func makeFractalSeed() -> Phrase {
        // m = steps 0, 3, 2, 7 above C4; times 1, 1/2, 1/4, 1/4
        let offsets = [0, 3, 2, 7]
        let durations = [Rational(1), Rational(1, 2), Rational(1, 4), Rational(1, 4)]
        var t = Rational.zero
        var notes: [Note] = []
        for (o, d) in zip(offsets, durations) {
            notes.append(Note(t, d, 35 + o))
            t = t + d
        }
        return Phrase(notes, in: .cMajor)
    }

    func testSelfSimilarReadsLevelsOffTheSeed() throws {
        let seed = makeFractalSeed()
        let fractal = Program(title: "fractal", space: .cMajor, seeds: ["S": seed],
                              root: .selfSimilar(seed: "S", child: .seed("S"),
                                                 spacing: seed.end))
        let big = try fractal.evaluate()
        XCTAssertEqual(big.count, 16)
        let levels = (0 ..< 4).map { big.notes[4 * $0].pitch.step - 35 }
        XCTAssertEqual(levels, [0, 3, 2, 7])
    }

    func testDerivingTheLevelsBeatsStatingThem() throws {
        let seed = makeFractalSeed()
        let offsets = [0, 3, 2, 7]

        let derived = Program(title: "derived", space: .cMajor, seeds: ["S": seed],
                              root: .selfSimilar(seed: "S", child: .seed("S"),
                                                 spacing: seed.end))
        let stated = Program(
            title: "stated", space: .cMajor, seeds: ["S": seed],
            root: .place(offsets.enumerated().map { i, o in
                PlaceItem(at: seed.end * Rational(i),
                          child: .apply(.translate(o), .seed("S")))
            })
        )

        XCTAssertEqual(try derived.evaluate(), try stated.evaluate(),
                       "both spellings must produce the same music")
        XCTAssertLessThan(derived.bitCost, stated.bitCost)
        XCTAssertLessThan(derived.bitCost, try derived.evaluate().literalBitCost)
    }

    // MARK: - The zipper

    func testZipperProducesCompoundMelody() throws {
        let upper = Phrase([0, 1, 2, 4].enumerated().map { i, s in
            Note(Rational(i, 2), Rational(1, 2), 35 + s)
        }, in: .cMajor)

        let program = Program(
            title: "zip demo", space: .cMajor, seeds: ["U": upper],
            root: .zip(left: .seed("U"),
                       right: .apply(.invert(about: 35), .seed("U")),
                       stride: Rational(1, 4))
        )
        let out = try program.evaluate()
        XCTAssertEqual(out.count, 8)
        // The surface line leaps wildly while the two implied voices are smooth. That gap is
        // exactly what the zipper is not paying for.
        XCTAssertEqual(out.midis, [60, 60, 62, 59, 64, 57, 67, 53])
        XCTAssertLessThan(program.bitCost, out.literalBitCost)
    }

    // MARK: - Round trips

    func testProgramSurvivesJSONRoundTrip() throws {
        let program = Program(
            title: "round trip", space: .cMajor, seeds: ["S": cde],
            definitions: [.init(name: "A", body: .apply(.translate(4), .seed("S")))],
            root: .place([
                PlaceItem(at: Rational(0), child: .seed("S")),
                PlaceItem(at: Rational(4), child: .ref("A"))
            ])
        )
        let data = try JSONEncoder().encode(program)
        let back = try JSONDecoder().decode(Program.self, from: data)
        XCTAssertEqual(try back.evaluate(), try program.evaluate())
        XCTAssertEqual(back.bitCost, program.bitCost, accuracy: 1e-9)
    }
}
