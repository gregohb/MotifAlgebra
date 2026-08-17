//
//  Similarity.swift
//  MotifAlgebra
//
//  The similarity classes, defined on step-interval vectors exactly as specified in the notes:
//
//      similar             jᵢ · kᵢ ≥ 0 for all i
//      strictly similar    for each i: either jᵢ = kᵢ = 0, or jᵢ · kᵢ > 0
//      inversely similar   for each i: either jᵢ = kᵢ = 0, or jᵢ · kᵢ < 0
//
//  These are sign-vector conditions: strictly similar means σ(k) = σ(j); inversely similar means
//  σ(k) = −σ(j); plain similar is the looser componentwise-compatible relation. So the classes
//  form a filtration by how much of the interval vector a claim actually pins down.
//
//  IMPORTANT — plain `similar` admits a degenerate case, and it is not hypothetical. `jᵢ·kᵢ ≥ 0`
//  holds when kᵢ = 0 and jᵢ ≠ 0, so a candidate that simply repeats one pitch is "similar" to
//  every motif of the right length. Measured against a shuffled null model, four-note contour
//  matching scored 22.6% on real music and 15.8% on shuffled — about 70% of short contour
//  matches were chance. `strictlySimilar` is the honest default; `similar` should never be
//  reported without its null-model baseline beside it.
//
//  Under MDL none of this needs a ranked list of tiers. A strict-similarity claim specifies the
//  sign vector and nothing else, buying (n−1)·log₂3 bits — about 8 bits for a six-note motif,
//  against a literal cost near 50 — so it must be cheap to state or frequently reused to
//  survive. `informationContent` below is that number.
//

import Foundation

public enum Similarity: String, Codable, Sendable, CaseIterable, CustomStringConvertible {

    /// Identical interval vectors — same shape, same sizes.
    case congruent

    /// Same signs throughout, magnitudes free. Zeros must correspond.
    case strictlySimilar

    /// Every sign flipped. Zeros must correspond.
    case inverselySimilar

    /// No opposing motion, but a zero may face a non-zero. The loose, chance-prone class.
    case similar

    /// None of the above.
    case unrelated

    public var description: String { rawValue }

    /// True when this class is tight enough to report without a null-model baseline.
    public var isFalsifiableOnItsOwn: Bool {
        switch self {
        case .congruent, .strictlySimilar, .inverselySimilar: return true
        case .similar, .unrelated: return false
        }
    }

    /// Classify a candidate interval vector against a reference. Returns the tightest class
    /// that holds.
    public static func classify(reference j: [Int], candidate k: [Int]) -> Similarity {
        guard j.count == k.count, !j.isEmpty else { return .unrelated }
        if j == k { return .congruent }
        if zip(j, k).allSatisfy({ ($0 == 0 && $1 == 0) || $0 * $1 > 0 }) {
            return .strictlySimilar
        }
        if zip(j, k).allSatisfy({ ($0 == 0 && $1 == 0) || $0 * $1 < 0 }) {
            return .inverselySimilar
        }
        if zip(j, k).allSatisfy({ $0 * $1 >= 0 }) {
            return .similar
        }
        return .unrelated
    }

    public static func classify(reference: Phrase, candidate: Phrase) -> Similarity {
        classify(reference: reference.stepIntervals, candidate: candidate.stepIntervals)
    }

    /// Bits a claim of this class actually buys, for a motif of `noteCount` notes.
    ///
    /// A sign vector over n−1 intervals carries (n−1)·log₂3 bits. Congruence carries the whole
    /// interval vector, so its content is measured elsewhere — by the literal cost of the
    /// intervals themselves. This is what replaces `hierarchicalOrder`: not a ranking, a number.
    public func informationContent(noteCount: Int) -> Double {
        let intervals = max(0, noteCount - 1)
        switch self {
        case .congruent:
            return .infinity          // fully determined; priced by the interval encoding
        case .strictlySimilar, .inverselySimilar:
            return Double(intervals) * log2(3.0)
        case .similar:
            // Weaker than a full sign vector: a zero in the candidate is unconstrained.
            return Double(intervals) * log2(2.0)
        case .unrelated:
            return 0
        }
    }
}
