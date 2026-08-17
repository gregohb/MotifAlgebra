//
//  Note.swift
//  MotifAlgebra
//
//  Notes and phrases.
//
//  The canonical ordering here is TOTAL — it breaks ties all the way down to velocity. That
//  matters more than it looks: Swift's `sort` is not guaranteed stable, so a key that stopped at
//  duration left two notes differing only in voice free to order either way, which made phrase
//  equality and `reproducesExactly` nondeterministic. A two-voice unison is exactly that case,
//  and overlay exists to produce two-voice unisons.
//

import Foundation

public struct Note: Hashable, Codable, Sendable, CustomStringConvertible {

    public var onset: Rational
    public var duration: Rational
    public var pitch: Pitch
    public var velocity: Int
    public var voice: Int

    public init(onset: Rational,
                duration: Rational,
                pitch: Pitch,
                velocity: Int = 80,
                voice: Int = -1) {
        self.onset = onset
        self.duration = duration
        self.pitch = pitch
        self.velocity = velocity
        self.voice = voice
    }

    /// Convenience for hand-written derivations and tests.
    public init(_ onset: Rational, _ duration: Rational, _ step: Int, alteration: Int = 0) {
        self.init(onset: onset,
                  duration: duration,
                  pitch: Pitch(step: step, alteration: alteration))
    }

    public var end: Rational { onset + duration }

    public func midi(in space: Space) -> Int { pitch.midi(in: space) }

    public func matchesPitchAndTime(_ other: Note) -> Bool {
        onset == other.onset && duration == other.duration && pitch == other.pitch
    }

    public var description: String { "\(pitch)@\(onset)+\(duration)" }

    /// The total order. No two distinct notes compare equal under it, so the sort is
    /// deterministic regardless of whether the underlying algorithm is stable.
    public static func canonicallyPrecedes(_ a: Note, _ b: Note) -> Bool {
        if a.onset != b.onset { return a.onset < b.onset }
        if a.pitch.step != b.pitch.step { return a.pitch.step < b.pitch.step }
        if a.pitch.alteration != b.pitch.alteration {
            return a.pitch.alteration < b.pitch.alteration
        }
        if a.duration != b.duration { return a.duration < b.duration }
        if a.voice != b.voice { return a.voice < b.voice }
        return a.velocity < b.velocity
    }
}

// MARK: - Phrase

public struct Phrase: Hashable, Codable, Sendable, CustomStringConvertible {

    public private(set) var notes: [Note]
    public var space: Space

    public init(_ notes: [Note], in space: Space = .cMajor) {
        self.notes = notes.sorted(by: Note.canonicallyPrecedes)
        self.space = space
    }

    public var count: Int { notes.count }
    public var isEmpty: Bool { notes.isEmpty }

    public var start: Rational { notes.first?.onset ?? .zero }
    public var end: Rational { notes.map(\.end).max() ?? .zero }
    public var span: Rational { end - start }

    public var midis: [Int] { notes.map { $0.midi(in: space) } }
    public var steps: [Int] { notes.map(\.pitch.step) }

    /// Step-interval vector — the object the similarity classes are defined on.
    public var stepIntervals: [Int] {
        guard notes.count > 1 else { return [] }
        return (1 ..< notes.count).map { notes[$0].pitch.step - notes[$0 - 1].pitch.step }
    }

    public func normalizedToZero() -> Phrase {
        let s = start
        if s.isZero { return self }
        return Phrase(notes.map { n in
            var m = n; m.onset = n.onset - s; return m
        }, in: space)
    }

    public func shifted(by delta: Rational) -> Phrase {
        Phrase(notes.map { n in
            var m = n; m.onset = n.onset + delta; return m
        }, in: space)
    }

    public func withVoice(_ v: Int) -> Phrase {
        Phrase(notes.map { n in
            var m = n; m.voice = v; return m
        }, in: space)
    }

    public var description: String {
        "[" + notes.map(\.description).joined(separator: " ") + "]"
    }
}
