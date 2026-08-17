//
//  Rational.swift
//  MotifAlgebra
//
//  Exact rational arithmetic for musical time.
//
//  Musical time is rational, not real. A triplet is 1/3, not 0.333333. Diminution by half is
//  exactly 1/2. Once durations become Double, `scale(2) ∘ scale(1/2) == identity` stops being
//  checkable with `==`, tolerance comparisons creep into the matcher, and — as happened in
//  Cantus — a `timeFactor = 0.5` silently loosens a rhythm score until the order of the
//  transform list is choosing the analysis.
//
//  Rational also has an exact, finite bit-cost (numerator plus denominator). A Double does not,
//  and the MDL scoring needs one.
//

import Foundation

public struct Rational: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {

    public let num: Int
    public let den: Int

    // MARK: - Construction

    public init(_ num: Int, _ den: Int = 1) {
        precondition(den != 0, "Rational: zero denominator")
        var n = num
        var d = den
        if d < 0 { n = -n; d = -d }
        let g = Rational.gcd(abs(n), d)
        if g > 1 { n /= g; d /= g }
        self.num = n
        self.den = d
    }

    /// Best rational approximation with denominator <= maxDen (Stern–Brocot).
    ///
    /// Use ONLY at the I/O boundary — importing a MIDI file whose ticks have been divided out.
    /// Never inside the algebra. If this is being called mid-derivation, something upstream has
    /// already lost exactness.
    public init(approximating x: Double, maxDenominator maxDen: Int = 960) {
        if x.isNaN || x.isInfinite { self.init(0); return }
        if abs(x) > Double(Int.max / 4) { self.init(x < 0 ? Int.min / 4 : Int.max / 4); return }
        let negative = x < 0
        let v = abs(x)
        var loN = 0, loD = 1
        var hiN = 1, hiD = 0
        var bestN = 0, bestD = 1
        for _ in 0 ..< 64 {
            let midN = loN + hiN
            let midD = loD + hiD
            if midD > maxDen { break }
            bestN = midN
            bestD = midD
            let mid = Double(midN) / Double(midD)
            if abs(mid - v) < 1e-12 { break }
            if mid < v { loN = midN; loD = midD } else { hiN = midN; hiD = midD }
        }
        if bestD == 0 { bestD = 1 }
        self.init(negative ? -bestN : bestN, bestD)
    }

    // MARK: - Constants

    public static let zero = Rational(0)
    public static let one = Rational(1)
    public static let half = Rational(1, 2)
    public static let quarter = Rational(1, 4)
    public static let third = Rational(1, 3)

    // MARK: - Arithmetic

    public static func + (a: Rational, b: Rational) -> Rational {
        Rational(a.num * b.den + b.num * a.den, a.den * b.den)
    }

    public static func - (a: Rational, b: Rational) -> Rational {
        Rational(a.num * b.den - b.num * a.den, a.den * b.den)
    }

    public static func * (a: Rational, b: Rational) -> Rational {
        Rational(a.num * b.num, a.den * b.den)
    }

    public static func / (a: Rational, b: Rational) -> Rational {
        precondition(b.num != 0, "Rational: division by zero")
        return Rational(a.num * b.den, a.den * b.num)
    }

    public static prefix func - (a: Rational) -> Rational { Rational(-a.num, a.den) }

    public var reciprocal: Rational {
        precondition(num != 0, "Rational: reciprocal of zero")
        return Rational(den, num)
    }

    public var isZero: Bool { num == 0 }
    public var isOne: Bool { num == 1 && den == 1 }
    public var isNegative: Bool { num < 0 }
    public var absolute: Rational { Rational(abs(num), den) }

    public static func < (a: Rational, b: Rational) -> Bool {
        a.num * b.den < b.num * a.den
    }

    // MARK: - Conversion

    public var doubleValue: Double { Double(num) / Double(den) }

    /// Nearest integer, ties away from zero. **Pure integer arithmetic** — no Double round trip.
    ///
    /// This is called by `PitchMap.scale`, the one map where rounding is load-bearing: it is
    /// where non-invertibility genuinely lives, so it must be exactly specified rather than
    /// inherited from floating point.
    public var roundedToInt: Int {
        num >= 0
            ? (2 * num + den) / (2 * den)
            : -((-2 * num + den) / (2 * den))
    }

    public var description: String { den == 1 ? "\(num)" : "\(num)/\(den)" }

    // MARK: - Helpers

    public static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x % y) }
        return x == 0 ? 1 : x
    }

    public static func lcm(_ a: Int, _ b: Int) -> Int {
        abs(a / gcd(a, b) * b)
    }
}

extension Rational: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self.init(value) }
}
