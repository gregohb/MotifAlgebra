//
//  Maps.swift
//  MotifAlgebra
//
//  The primitive maps: two per axis, not four.
//
//  This follows the four-parameter form  C·m(Ax − B) + D  from the Group Action notes. Each
//  axis gets a translation and a SIGNED scaling, and the sign does the work that separate cases
//  used to do:
//
//      pitch scale by -1  ==  inversion about the anchor
//      time  scale by -1  ==  retrograde
//
//  Collapsing them is not tidying. The previous four-case design could not express
//  retrograde-with-augmentation — time factor -2 — as a single map at all; it had to be faked
//  as a composition, which cost two opcodes and distorted the bit accounting. Worse, `invert`
//  and `scale(-1)` were separate code paths that disagreed with each other by two semitones on
//  every chromatic note, because one negated the alteration and the other did not. With one
//  case there is one answer.
//

import Foundation

// MARK: - Pitch maps

public enum PitchMap: Hashable, Codable, Sendable, CustomStringConvertible {

    /// Move `steps` step-units. Exact and invertible on spelled pitch, always — the alteration
    /// rides along untouched because it is stored rather than re-derived.
    case translate(steps: Int)

    /// step' = anchor + round(factor · (step − anchor));  alteration' = round(factor · alteration)
    ///
    /// The alteration scales WITH the factor rather than riding along, so that factor = -1
    /// sends an ascending semitone to a descending one — C-sharp inverted about C is C-flat,
    /// which is the musically correct answer and the one that makes inversion an involution.
    ///
    /// |factor| ≠ 1 rounds, and rounding is where non-invertibility genuinely lives.
    case scale(factor: Rational, anchor: Int)

    public func apply(to p: Pitch) -> Pitch {
        switch self {
        case .translate(let steps):
            return Pitch(step: p.step + steps, alteration: p.alteration)
        case .scale(let factor, let anchor):
            let moved = (Rational(p.step - anchor) * factor).roundedToInt
            let alt = (Rational(p.alteration) * factor).roundedToInt
            return Pitch(step: anchor + moved, alteration: alt)
        }
    }

    public var inverse: PitchMap? {
        switch self {
        case .translate(let steps):
            return .translate(steps: -steps)
        case .scale(let factor, let anchor):
            guard factor.absolute.isOne else { return nil }
            return .scale(factor: factor.reciprocal, anchor: anchor)
        }
    }

    /// Convenience: inversion is scale by -1. Provided as a name, not as a separate case.
    public static func invert(about anchor: Int) -> PitchMap {
        .scale(factor: Rational(-1), anchor: anchor)
    }

    public var bitCost: Double {
        switch self {
        case .translate(let steps):
            return Cost.choice(prior: 0.55) + Cost.integer(steps)
        case .scale(let factor, let anchor):
            return Cost.choice(prior: 0.25) + Cost.rational(factor) + Cost.integer(anchor)
        }
    }

    public var description: String {
        switch self {
        case .translate(let s): return "P.T\(s >= 0 ? "+" : "")\(s)"
        case .scale(let f, let a): return "P.S(x\(f)@\(a))"
        }
    }
}

// MARK: - Time maps

public enum TimeMap: Hashable, Codable, Sendable, CustomStringConvertible {

    case translate(delta: Rational)

    /// factor > 0 augments or diminishes. factor < 0 reverses within the phrase's own span and
    /// scales by |factor|; factor == -1 is classic retrograde. factor == 0 annihilates, and is
    /// therefore the one map with no inverse for a reason that has nothing to do with rounding.
    case scale(factor: Rational)

    public func apply(to phrase: Phrase) -> Phrase {
        switch self {
        case .translate(let delta):
            return phrase.shifted(by: delta)

        case .scale(let factor):
            if factor.isZero { return Phrase([], in: phrase.space) }
            let origin = phrase.start
            let zeroed = phrase.normalizedToZero()
            let span = zeroed.end
            let magnitude = factor.absolute
            let out = zeroed.notes.map { n -> Note in
                var m = n
                m.duration = n.duration * magnitude
                m.onset = factor.isNegative ? (span - n.end) * magnitude : n.onset * factor
                return m
            }
            return Phrase(out, in: phrase.space).shifted(by: origin)
        }
    }

    public var inverse: TimeMap? {
        switch self {
        case .translate(let delta):
            return .translate(delta: -delta)
        case .scale(let factor):
            guard !factor.isZero else { return nil }
            return .scale(factor: factor.reciprocal)
        }
    }

    /// Convenience: retrograde is scale by -1.
    public static var retrograde: TimeMap { .scale(factor: Rational(-1)) }

    public var bitCost: Double {
        switch self {
        case .translate(let d): return Cost.choice(prior: 0.45) + Cost.rational(d)
        case .scale(let f): return Cost.choice(prior: 0.35) + Cost.rational(f)
        }
    }

    public var description: String {
        switch self {
        case .translate(let d): return "T.T\(d.isNegative ? "" : "+")\(d)"
        case .scale(let f): return "T.S(x\(f))"
        }
    }
}
