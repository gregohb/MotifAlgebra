//
//  BitCost.swift
//  MotifAlgebra
//
//  Everything is priced in bits, and the prices are universal codes rather than tuned weights.
//
//  This is the whole defence against Réti's failure mode. With a rich enough transformation set
//  any two fragments can be related, and the analysis becomes unfalsifiable. The fix is not a
//  better similarity threshold — it is charging for the hypothesis:
//
//      an analysis explains material only when
//          bits(seed) + bits(transforms) + bits(residual)  <  bits(literal encoding)
//
//  One criterion replaces eleven tuned constants. It penalises exotic transformations
//  automatically, because they cost more bits to name. It lets fragments compete fairly against
//  full-length matches. And it makes cross-composer comparison a number — bits per note — rather
//  than an adjective.
//

import Foundation

public enum Cost {

    /// Elias gamma: the length in bits of a self-delimiting code for a positive integer.
    ///
    /// Computed from the integer's bit length, not from `log2` on a Double. The float version
    /// happened to agree over every value tested, but "verified over a range" is weaker than
    /// "cannot differ", and this costs nothing.
    public static func gamma(_ m: Int) -> Double {
        precondition(m >= 1, "Cost.gamma requires m >= 1")
        let floorLog2 = Int.bitWidth - m.leadingZeroBitCount - 1
        return 2.0 * Double(floorLog2) + 1.0
    }

    /// Signed integer via zig-zag mapping onto the positives, then gamma.
    /// Symmetric about zero: 0 costs 1 bit, ±1 cost 3, ±2 and ±3 cost 5.
    public static func integer(_ n: Int) -> Double {
        let zigzag = n >= 0 ? 2 * n : -2 * n - 1
        return gamma(zigzag + 1)
    }

    public static func rational(_ r: Rational) -> Double {
        integer(r.num) + integer(r.den)
    }

    /// Bits to select an option of the given prior probability.
    public static func choice(prior p: Double) -> Double {
        precondition(p > 0 && p <= 1, "Cost.choice requires 0 < prior <= 1")
        return -log2(p)
    }

    /// Bits to name one of `n` equally likely alternatives.
    public static func index(outOf n: Int) -> Double {
        log2(Double(max(1, n)))
    }
}

public extension Phrase {

    /// Bits to write the phrase out note by note, with no model: first pitch absolute, then
    /// deltas. This is the number every analysis has to beat.
    var literalBitCost: Double {
        guard let first = notes.first else { return Cost.integer(0) }
        var total = Cost.integer(notes.count)
        total += Cost.integer(first.pitch.step)
        total += Cost.integer(first.pitch.alteration)
        total += Cost.rational(first.duration)
        for i in 1 ..< notes.count {
            total += Cost.integer(notes[i].pitch.step - notes[i - 1].pitch.step)
            total += Cost.integer(notes[i].pitch.alteration)
            total += Cost.rational(notes[i].onset - notes[i - 1].onset)
            total += Cost.rational(notes[i].duration)
        }
        return total
    }

    var literalBitsPerNote: Double {
        notes.isEmpty ? 0 : literalBitCost / Double(notes.count)
    }
}

// MARK: - Verdict

/// The MDL judgement, reported in full so that a reader can see what was traded for what.
public struct Verdict: Codable, Sendable, CustomStringConvertible {

    public let modelBits: Double
    public let residualBits: Double
    public let literalBits: Double
    public let noteCount: Int

    public init(modelBits: Double, residualBits: Double, literalBits: Double, noteCount: Int) {
        self.modelBits = modelBits
        self.residualBits = residualBits
        self.literalBits = literalBits
        self.noteCount = noteCount
    }

    public var totalBits: Double { modelBits + residualBits }

    /// The criterion. Everything else in this type is diagnostics.
    public var explains: Bool { totalBits < literalBits }

    public var bitsSaved: Double { literalBits - totalBits }
    public var compressionRatio: Double { literalBits / max(totalBits, .leastNormalMagnitude) }
    public var bitsPerNote: Double { noteCount == 0 ? 0 : totalBits / Double(noteCount) }

    public var description: String {
        String(format: "%@ %.1f b (model %.1f + residual %.1f) vs literal %.1f b — %.2f b/note",
               explains ? "EXPLAINS:" : "does not explain:",
               totalBits, modelBits, residualBits, literalBits, bitsPerNote)
    }
}
