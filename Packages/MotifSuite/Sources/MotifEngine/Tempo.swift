//
//  Tempo.swift
//  MotifEngine
//
//  Tempo, ported from AMT005's AUTempoController.
//
//  Two changes. The first is that this is a value, not an ObservableObject. AMT005's tempo was a
//  reference type with @Published state, which meant the conversion functions — pure arithmetic
//  on a single number — could only be called by something holding a live controller. Tests of the
//  scheduler had to construct a Combine publisher to ask what 90 BPM does to a half note.
//
//  The second is that NoteValue.beats returns a Rational. It returned Double there, and the
//  triplet cases were written as `1.0 / 3.0` — which is the exact thing Rational exists to
//  prevent. A triplet eighth is a third of a quarter note, exactly, and the algebra can only
//  check `augment(3) ∘ diminish(3) == identity` if it stays that way.
//
//  Seconds remain Double, and should. Musical time is rational; clock time is not, and the audio
//  hardware wants a real number. The conversion happens here, once, at the point where music
//  becomes sound.
//

import Foundation
import MotifAlgebra

public struct Tempo: Hashable, Sendable, CustomStringConvertible {

    public static let minimumBPM: Double = 20.0
    public static let maximumBPM: Double = 300.0

    public private(set) var bpm: Double

    public init(bpm: Double = 120.0) {
        self.bpm = Self.clamped(bpm)
    }

    public init(_ marking: Marking) {
        self.init(bpm: marking.bpm)
    }

    private static func clamped(_ value: Double) -> Double {
        // NaN has no ordering, so min/max cannot clamp it — it needs the explicit fallback.
        // The infinities do compare, and clamp to the limits like any other out-of-range value;
        // treating them as "no tempo given" and silently returning 120 would be wrong.
        guard !value.isNaN else { return 120.0 }
        return max(minimumBPM, min(maximumBPM, value))
    }

    // MARK: - Conversion

    public var secondsPerBeat: Double { 60.0 / bpm }
    public var beatsPerSecond: Double { bpm / 60.0 }

    /// Exact musical time to clock time. The only lossy step in playback, and it happens once
    /// per event rather than once per scheduler tick.
    public func seconds(_ beats: Rational) -> Double {
        beats.doubleValue * secondsPerBeat
    }

    public func beats(seconds: Double) -> Double {
        seconds * beatsPerSecond
    }

    // MARK: - Adjustment

    public func scaled(by factor: Double) -> Tempo { Tempo(bpm: bpm * factor) }
    public func adjusted(by delta: Double) -> Tempo { Tempo(bpm: bpm + delta) }
    public var doubled: Tempo { scaled(by: 2) }
    public var halved: Tempo { scaled(by: 0.5) }

    public var isAtLimit: Bool {
        bpm <= Self.minimumBPM || bpm >= Self.maximumBPM
    }

    // MARK: - Markings

    public enum Marking: String, CaseIterable, Sendable {
        case grave, largo, lento, adagio, andante, moderato
        case allegretto, allegro, vivace, presto, prestissimo

        public var bpm: Double {
            switch self {
            case .grave: return 40
            case .largo: return 50
            case .lento: return 60
            case .adagio: return 70
            case .andante: return 85
            case .moderato: return 100
            case .allegretto: return 115
            case .allegro: return 130
            case .vivace: return 150
            case .presto: return 180
            case .prestissimo: return 200
            }
        }

        public var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

        public var gloss: String {
            switch self {
            case .grave: return "very slow"
            case .largo: return "slow and broad"
            case .lento: return "slow"
            case .adagio: return "slow and stately"
            case .andante: return "walking pace"
            case .moderato: return "moderate"
            case .allegretto: return "moderately fast"
            case .allegro: return "fast"
            case .vivace: return "lively and fast"
            case .presto: return "very fast"
            case .prestissimo: return "extremely fast"
            }
        }
    }

    public var closestMarking: Marking {
        Marking.allCases.min { abs($0.bpm - bpm) < abs($1.bpm - bpm) } ?? .moderato
    }

    public var description: String {
        let marking = closestMarking
        let rounded = Int(bpm.rounded())
        return rounded == Int(marking.bpm)
            ? "\(marking.name) (\(rounded) BPM)"
            : "\(rounded) BPM (near \(marking.name))"
    }
}

// MARK: - Note values

/// Note values as exact fractions of a quarter note.
///
/// AMT005 wrote the triplets as `1.0 / 3.0`, `2.0 / 3.0`, `8.0 / 3.0`. Three triplet eighths
/// summed to 0.99999999999999989 rather than 1, so a bar of triplets did not close, and the
/// rhythm matcher needed a tolerance to accept music that was exactly right.
public enum NoteValue: String, CaseIterable, Sendable {

    case whole, half, quarter, eighth, sixteenth, thirtySecond, sixtyFourth
    case dottedWhole, dottedHalf, dottedQuarter, dottedEighth, dottedSixteenth
    case tripletWhole, tripletHalf, tripletQuarter, tripletEighth, tripletSixteenth

    public var beats: Rational {
        switch self {
        case .whole: return Rational(4)
        case .half: return Rational(2)
        case .quarter: return Rational(1)
        case .eighth: return Rational(1, 2)
        case .sixteenth: return Rational(1, 4)
        case .thirtySecond: return Rational(1, 8)
        case .sixtyFourth: return Rational(1, 16)

        case .dottedWhole: return Rational(6)
        case .dottedHalf: return Rational(3)
        case .dottedQuarter: return Rational(3, 2)
        case .dottedEighth: return Rational(3, 4)
        case .dottedSixteenth: return Rational(3, 8)

        case .tripletWhole: return Rational(8, 3)
        case .tripletHalf: return Rational(4, 3)
        case .tripletQuarter: return Rational(2, 3)
        case .tripletEighth: return Rational(1, 3)
        case .tripletSixteenth: return Rational(1, 6)
        }
    }

    public var name: String {
        switch self {
        case .whole: return "Whole"
        case .half: return "Half"
        case .quarter: return "Quarter"
        case .eighth: return "Eighth"
        case .sixteenth: return "16th"
        case .thirtySecond: return "32nd"
        case .sixtyFourth: return "64th"
        case .dottedWhole: return "Dotted whole"
        case .dottedHalf: return "Dotted half"
        case .dottedQuarter: return "Dotted quarter"
        case .dottedEighth: return "Dotted eighth"
        case .dottedSixteenth: return "Dotted 16th"
        case .tripletWhole: return "Whole triplet"
        case .tripletHalf: return "Half triplet"
        case .tripletQuarter: return "Quarter triplet"
        case .tripletEighth: return "Eighth triplet"
        case .tripletSixteenth: return "16th triplet"
        }
    }

    /// The note value written exactly as this duration, if there is one.
    public static func matching(_ beats: Rational) -> NoteValue? {
        allCases.first { $0.beats == beats }
    }
}
