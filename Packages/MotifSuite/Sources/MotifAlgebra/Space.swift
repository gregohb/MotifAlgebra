//
//  Space.swift
//  MotifAlgebra
//
//  The lattice a step index counts in.
//
//  There is no `chromatic` special case. Chromatic is simply the space whose pattern is
//  0,1,…,11. Major, minor, pentatonic, octatonic and Xenakis sieves are all the same type with
//  different patterns, so no map needs to branch on which kind of space it is acting in.
//
//  Note what this type does NOT do: it never converts a MIDI number into a coordinate during
//  analysis. `nearestStep(ofMIDI:)` exists only for import, where spelling is genuinely unknown.
//  Deriving a coordinate from MIDI is lossy — it canonicalises, so an alteration that happens to
//  land on another scale degree is silently absorbed, and the inverse map then starts from the
//  wrong place. That was a real bug; it is fixed by storing spelling on the note instead.
//

import Foundation

public struct Space: Hashable, Codable, Sendable, CustomStringConvertible {

    /// Pitch class of step 0, in 0...11.
    public let tonicPitchClass: Int

    /// Ascending semitone offsets from the tonic, starting at 0, strictly increasing, all < 12.
    public let pattern: [Int]

    public let name: String

    public init(tonicPitchClass: Int, pattern: [Int], name: String = "") {
        precondition(!pattern.isEmpty, "Space: empty pattern")
        precondition(pattern[0] == 0, "Space: pattern must start at 0")
        self.tonicPitchClass = ((tonicPitchClass % 12) + 12) % 12
        self.pattern = pattern
        self.name = name.isEmpty ? "space(pc \(tonicPitchClass), \(pattern))" : name
    }

    public var degreeCount: Int { pattern.count }

    public var description: String { name }

    // MARK: - Coordinates

    /// Semitone height of an unaltered step index. Step 0 is the lowest tonic at or above 0.
    public func semitones(step: Int) -> Int {
        let n = degreeCount
        let oct = Int((Double(step) / Double(n)).rounded(.down))
        let idx = step - oct * n
        return tonicPitchClass + 12 * oct + pattern[idx]
    }

    /// Import only. Returns the canonical spelling of a MIDI pitch — the largest step whose
    /// unaltered height is <= the pitch, plus the leftover semitones.
    ///
    /// Never call this inside the algebra. It is the lossy direction.
    public func nearestStep(ofMIDI midiPitch: Int) -> (step: Int, alteration: Int) {
        let n = degreeCount
        var s = (midiPitch - tonicPitchClass) / 12 * n
        while semitones(step: s) > midiPitch { s -= 1 }
        while semitones(step: s + 1) <= midiPitch { s += 1 }
        return (s, midiPitch - semitones(step: s))
    }

    // MARK: - Standard spaces

    public static let majorPattern = [0, 2, 4, 5, 7, 9, 11]
    public static let naturalMinorPattern = [0, 2, 3, 5, 7, 8, 10]
    public static let harmonicMinorPattern = [0, 2, 3, 5, 7, 8, 11]
    public static let chromaticPattern = Array(0 ..< 12)

    public static let chromatic = Space(tonicPitchClass: 0,
                                        pattern: chromaticPattern,
                                        name: "chromatic")

    public static func major(_ pc: Int) -> Space {
        Space(tonicPitchClass: pc, pattern: majorPattern, name: "\(pitchClassName(pc)) major")
    }

    public static func minor(_ pc: Int) -> Space {
        Space(tonicPitchClass: pc, pattern: naturalMinorPattern,
              name: "\(pitchClassName(pc)) minor")
    }

    public static let cMajor = Space.major(0)
    public static let aMinor = Space.minor(9)

    public static func pitchClassName(_ pc: Int) -> String {
        let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        return names[((pc % 12) + 12) % 12]
    }
}
