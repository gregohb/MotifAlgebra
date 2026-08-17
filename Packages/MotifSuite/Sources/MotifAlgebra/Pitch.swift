//
//  Pitch.swift
//  MotifAlgebra
//
//  A SPELLED pitch — the single most important type in the package.
//
//  `step` is an absolute index into a space's lattice; `alteration` is semitones above the
//  unaltered degree. C-sharp is (step: C, alteration: +1); D-flat is (step: D, alteration: -1).
//  Both sound the same MIDI number and both are kept distinct.
//
//  This is stored state, never recomputed from a MIDI number. That single decision fixes four
//  separate problems at once:
//
//    * diatonic transposition becomes invertible on every pitch, not merely on in-scale ones
//    * inversion becomes an involution on every pitch
//    * enharmonic tones become distinguishable, which the modulation analysis requires
//    * `invert` and `scale(-1)` stop being two code paths that disagree
//
//  It is also just what notation has always done — MusicXML's step/octave/alter, music21's
//  Pitch.step/.alter. MIDI is the lossy representation; this is the faithful one.
//

import Foundation

public struct Pitch: Hashable, Codable, Sendable, CustomStringConvertible {

    /// Absolute step index in the governing space.
    public let step: Int

    /// Semitones above the unaltered degree. Zero for a diatonic note.
    public let alteration: Int

    public init(step: Int, alteration: Int = 0) {
        self.step = step
        self.alteration = alteration
    }

    /// Sounding MIDI number in a given space. Derived — never stored.
    public func midi(in space: Space) -> Int {
        space.semitones(step: step) + alteration
    }

    /// Import a MIDI number by taking the canonical spelling. Lossy by nature: it cannot know
    /// whether the source meant C-sharp or D-flat. Use only at the file boundary.
    public init(importingMIDI midiPitch: Int, in space: Space) {
        let c = space.nearestStep(ofMIDI: midiPitch)
        self.init(step: c.step, alteration: c.alteration)
    }

    public var isDiatonic: Bool { alteration == 0 }

    public var description: String {
        alteration == 0
            ? "s\(step)"
            : "s\(step)\(alteration > 0 ? "+" : "")\(alteration)"
    }

    /// Human-readable name in a space, e.g. "C#4".
    public func name(in space: Space) -> String {
        let n = space.degreeCount
        let oct = Int((Double(step) / Double(n)).rounded(.down))
        let idx = step - oct * n
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        let letter = n == 7 ? letters[idx] : "d\(idx)"
        let accidental: String
        switch alteration {
        case 0: accidental = ""
        case 1: accidental = "#"
        case 2: accidental = "##"
        case -1: accidental = "b"
        case -2: accidental = "bb"
        default: accidental = alteration > 0 ? "+\(alteration)" : "\(alteration)"
        }
        return "\(letter)\(accidental)\(oct - 1)"
    }
}
