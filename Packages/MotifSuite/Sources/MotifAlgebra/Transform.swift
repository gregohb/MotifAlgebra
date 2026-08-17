//
//  Transform.swift
//  MotifAlgebra
//
//  A transformation is a composable value, not a name from a list.
//
//  The type it replaces was a flat enum of thirty pre-composed cases — the Cartesian product of
//  transpose × retrograde × invert × augment × similarity-tier, enumerated by hand. Three things
//  were wrong with that, and all three are fixed here:
//
//    * adding one new operation multiplied the enum, along with every switch over it
//    * composition was inexpressible: `retrograde ∘ diminish ∘ T+7` had no representation,
//      so the DNA could not be a tree while the alphabet was a flat list of names
//    * parameters lived in a [String: Double] bag, which has no computable bit-cost, so no
//      MDL scoring could be built on top of it
//
//  Here thirty names become compositions of four constructors, each with an exact cost.
//
//  Pitch maps and time maps are kept in separate lists because they commute — that is a property
//  of the group (the diagonal affine group of the time/pitch plane is a direct product), not an
//  implementation convenience. Within each list, order is significant and preserved.
//

import Foundation

public struct Transform: Hashable, Codable, Sendable, CustomStringConvertible {

    public var pitchMaps: [PitchMap]
    public var timeMaps: [TimeMap]

    public init(pitchMaps: [PitchMap] = [], timeMaps: [TimeMap] = []) {
        self.pitchMaps = pitchMaps
        self.timeMaps = timeMaps
    }

    // MARK: - Constructors

    public static let identity = Transform()

    public static func translate(_ steps: Int) -> Transform {
        Transform(pitchMaps: [.translate(steps: steps)])
    }

    public static func invert(about anchor: Int) -> Transform {
        Transform(pitchMaps: [.invert(about: anchor)])
    }

    public static func pitchScale(_ factor: Rational, anchor: Int) -> Transform {
        Transform(pitchMaps: [.scale(factor: factor, anchor: anchor)])
    }

    public static func shift(_ delta: Rational) -> Transform {
        Transform(timeMaps: [.translate(delta: delta)])
    }

    public static func timeScale(_ factor: Rational) -> Transform {
        Transform(timeMaps: [.scale(factor: factor)])
    }

    public static let retrograde = Transform(timeMaps: [.retrograde])

    public static func augment(_ factor: Rational) -> Transform { timeScale(factor) }
    public static func diminish(_ factor: Rational) -> Transform { timeScale(factor.reciprocal) }

    // MARK: - Composition

    /// `a.then(b)` applies `a`, then `b`.
    public func then(_ other: Transform) -> Transform {
        Transform(pitchMaps: pitchMaps + other.pitchMaps,
                  timeMaps: timeMaps + other.timeMaps)
    }

    public var inverse: Transform? {
        var ip: [PitchMap] = []
        for m in pitchMaps.reversed() {
            guard let i = m.inverse else { return nil }
            ip.append(i)
        }
        var it: [TimeMap] = []
        for m in timeMaps.reversed() {
            guard let i = m.inverse else { return nil }
            it.append(i)
        }
        return Transform(pitchMaps: ip, timeMaps: it)
    }

    public var isInvertible: Bool { inverse != nil }

    // MARK: - Action

    public func apply(to phrase: Phrase) -> Phrase {
        var result = phrase
        for m in timeMaps {
            result = m.apply(to: result)
        }
        guard !pitchMaps.isEmpty else { return result }
        let mapped = result.notes.map { n -> Note in
            var m = n
            var p = n.pitch
            for map in pitchMaps { p = map.apply(to: p) }
            m.pitch = p
            return m
        }
        return Phrase(mapped, in: result.space)
    }

    // MARK: - Cost

    public var bitCost: Double {
        var total = Cost.integer(pitchMaps.count) + Cost.integer(timeMaps.count)
        for m in pitchMaps { total += m.bitCost }
        for m in timeMaps { total += m.bitCost }
        return total
    }

    public var description: String {
        let parts = timeMaps.map(\.description) + pitchMaps.map(\.description)
        return parts.isEmpty ? "id" : parts.joined(separator: " ∘ ")
    }
}
