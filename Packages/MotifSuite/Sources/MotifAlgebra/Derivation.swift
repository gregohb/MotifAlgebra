//
//  Derivation.swift
//  MotifAlgebra
//
//  The DNA: a straight-line program, not a list.
//
//  A flat "seed plus set of transformations" cannot express what music does. Scale maps do not
//  commute, so order is structure; and real music varies its variations, so a variant is itself
//  a seed for further variation. What fits is a program whose terminals are motifs, whose rules
//  are parameterised transformations, and — the part that makes it compress — whose named
//  definitions can be cited more than once, so a shared subtree is paid for once.
//
//  That is the whole reason a tree beats a list under MDL. In a fugue, the answer, the
//  countersubject entries and the stretto are not eleven independent facts; they are one fact
//  cited eleven times. A list must restate it. A program says `ref("subject")`.
//
//  Building the evaluator is straightforward. Inducing the program from a score is the research
//  problem. The evaluator comes first deliberately: hand-write a derivation for a piece already
//  understood, prove it reproduces the score note-for-note, and the seed-swapping demo works
//  without discovery being solved at all.
//

import Foundation

public struct PlaceItem: Hashable, Codable, Sendable {
    public var at: Rational
    public var child: Derivation
    public init(at: Rational, child: Derivation) {
        self.at = at
        self.child = child
    }
}

public struct OverlayItem: Hashable, Codable, Sendable {
    public var at: Rational
    public var voice: Int
    public var child: Derivation
    public init(at: Rational, voice: Int, child: Derivation) {
        self.at = at
        self.voice = voice
        self.child = child
    }
}

public indirect enum Derivation: Hashable, Codable, Sendable, CustomStringConvertible {

    /// A terminal: one of the program's declared motifs.
    case seed(String)

    /// A citation of a named definition. Cheap — this is where reuse pays.
    case ref(String)

    /// Apply a transformation to a sub-derivation.
    case apply(Transform, Derivation)

    /// Lay sub-derivations end to end at absolute onsets. Each child is normalised to zero
    /// before placement, so children stay position-independent and therefore reusable.
    case place([PlaceItem])

    /// Sound sub-derivations simultaneously — counterpoint.
    case overlay([OverlayItem])

    /// The fractal string. For each note *i* of `seed`, place a copy of `child` transposed by
    /// the seed's own step-interval from note 0 to note *i*, at onset *i* × `spacing`.
    ///
    /// The transposition levels are READ OFF the seed, so they cost nothing. That is precisely
    /// what self-similarity means, expressed as arithmetic rather than as a metaphor.
    case selfSimilar(seed: String, child: Derivation, spacing: Rational)

    /// The ZIPPER — the algebra's only binary operation. Interleaves two children note by note.
    ///
    /// Musically this is COMPOUND MELODY: a single line the ear resolves into two voices, which
    /// is exactly what Bach's solo violin and cello writing does. It is also the inverse of voice
    /// separation — a voice separator un-zips. So for a compound-melody movement the derivation
    /// is: separate voices, derive each, zip.
    ///
    /// It predicts something checkable: the saving grows with the registral separation of the
    /// implied voices, because a literal encoding pays for the wide alternating leaps of the
    /// surface line while the zipper pays for none of them.
    case zip(left: Derivation, right: Derivation, stride: Rational)

    public var description: String {
        switch self {
        case .seed(let n): return "seed(\(n))"
        case .ref(let n): return "&\(n)"
        case .apply(let t, let d): return "\(t) ▸ \(d)"
        case .place(let items):
            return "place{" + items.map { "\($0.at):\($0.child)" }.joined(separator: ", ") + "}"
        case .overlay(let items):
            return "overlay{" + items.map { "v\($0.voice)@\($0.at):\($0.child)" }
                .joined(separator: ", ") + "}"
        case .selfSimilar(let s, let c, let sp): return "fractal(\(s), \(c), ×\(sp))"
        case .zip(let l, let r, let st): return "zip(\(l), \(r), /\(st))"
        }
    }

    /// Bits to write this node down.
    ///
    /// `ref` costs only the opcode plus log2(number of definitions). That difference is the
    /// compression a tree buys over a list, expressed as arithmetic rather than asserted.
    public func bitCost(namedCount: Int, seedCount: Int) -> Double {
        switch self {
        case .seed:
            return Cost.choice(prior: 0.25) + Cost.index(outOf: seedCount)
        case .ref:
            return Cost.choice(prior: 0.35) + Cost.index(outOf: namedCount)
        case .apply(let t, let child):
            return Cost.choice(prior: 0.25) + t.bitCost
                 + child.bitCost(namedCount: namedCount, seedCount: seedCount)
        case .place(let items):
            return Cost.choice(prior: 0.09) + Cost.integer(items.count)
                 + items.reduce(0) { $0 + Cost.rational($1.at)
                     + $1.child.bitCost(namedCount: namedCount, seedCount: seedCount) }
        case .overlay(let items):
            return Cost.choice(prior: 0.05) + Cost.integer(items.count)
                 + items.reduce(0) { $0 + Cost.rational($1.at) + Cost.integer($1.voice)
                     + $1.child.bitCost(namedCount: namedCount, seedCount: seedCount) }
        case .selfSimilar(_, let child, let spacing):
            return Cost.choice(prior: 0.03) + Cost.index(outOf: seedCount)
                 + Cost.rational(spacing)
                 + child.bitCost(namedCount: namedCount, seedCount: seedCount)
        case .zip(let l, let r, let stride):
            return Cost.choice(prior: 0.06) + Cost.rational(stride)
                 + l.bitCost(namedCount: namedCount, seedCount: seedCount)
                 + r.bitCost(namedCount: namedCount, seedCount: seedCount)
        }
    }
}

// MARK: - Program

/// A complete analysis: a declared space, declared motifs, named definitions, and a root.
///
/// Both halves of the project live in this one type. Evaluate the root to GENERATE; compare its
/// cost against the literal encoding to ANALYSE.
public struct Program: Codable, Sendable {

    public var title: String
    public var space: Space
    public var seeds: [String: Phrase]

    /// Ordered, and a definition may only cite definitions declared before it. That keeps the
    /// program acyclic by construction, with no cycle check required.
    public var definitions: [Definition]

    public var root: Derivation

    public struct Definition: Hashable, Codable, Sendable {
        public var name: String
        public var body: Derivation
        public init(name: String, body: Derivation) {
            self.name = name
            self.body = body
        }
    }

    public init(title: String = "",
                space: Space = .cMajor,
                seeds: [String: Phrase] = [:],
                definitions: [Definition] = [],
                root: Derivation) {
        self.title = title
        self.space = space
        self.seeds = seeds
        self.definitions = definitions
        self.root = root
    }

    // MARK: Evaluation

    public enum EvalError: Error, CustomStringConvertible {
        case unknownSeed(String)
        case unknownDefinition(String)
        case emptySeed(String)
        public var description: String {
            switch self {
            case .unknownSeed(let n): return "unknown seed '\(n)'"
            case .unknownDefinition(let n): return "unknown definition '\(n)'"
            case .emptySeed(let n): return "seed '\(n)' is empty"
            }
        }
    }

    public func evaluate() throws -> Phrase {
        var memo: [String: Phrase] = [:]
        for def in definitions {
            memo[def.name] = try evaluate(def.body, memo: &memo)
        }
        return try evaluate(root, memo: &memo)
    }

    private func evaluate(_ node: Derivation, memo: inout [String: Phrase]) throws -> Phrase {
        switch node {

        case .seed(let name):
            guard let p = seeds[name] else { throw EvalError.unknownSeed(name) }
            return p

        case .ref(let name):
            guard let p = memo[name] else { throw EvalError.unknownDefinition(name) }
            return p

        case .apply(let t, let child):
            return t.apply(to: try evaluate(child, memo: &memo))

        case .place(let items):
            var all: [Note] = []
            for item in items {
                let p = try evaluate(item.child, memo: &memo)
                    .normalizedToZero().shifted(by: item.at)
                all.append(contentsOf: p.notes)
            }
            return Phrase(all, in: space)

        case .overlay(let items):
            var all: [Note] = []
            for item in items {
                let p = try evaluate(item.child, memo: &memo)
                    .normalizedToZero().shifted(by: item.at).withVoice(item.voice)
                all.append(contentsOf: p.notes)
            }
            return Phrase(all, in: space)

        case .selfSimilar(let seedName, let child, let spacing):
            guard let base = seeds[seedName] else { throw EvalError.unknownSeed(seedName) }
            guard let first = base.notes.first else { throw EvalError.emptySeed(seedName) }
            let body = try evaluate(child, memo: &memo).normalizedToZero()
            var all: [Note] = []
            for (i, bn) in base.notes.enumerated() {
                let level = bn.pitch.step - first.pitch.step
                let copy = Transform.translate(level).apply(to: body)
                    .shifted(by: spacing * Rational(i))
                all.append(contentsOf: copy.notes)
            }
            return Phrase(all, in: space)

        case .zip(let leftNode, let rightNode, let stride):
            let a = try evaluate(leftNode, memo: &memo).normalizedToZero()
            let b = try evaluate(rightNode, memo: &memo).normalizedToZero()
            var all: [Note] = []
            var t = Rational.zero
            let limit = max(a.notes.count, b.notes.count)
            for i in 0 ..< limit {
                for source in [a, b] where i < source.notes.count {
                    var n = source.notes[i]
                    n.onset = t
                    n.duration = stride
                    all.append(n)
                    t = t + stride
                }
            }
            return Phrase(all, in: space)
        }
    }

    // MARK: Description length

    /// Bits to write the whole program down: the space, the motifs literally, then the tree.
    public var bitCost: Double {
        var total = Cost.integer(space.tonicPitchClass) + Cost.integer(space.degreeCount)
        total += space.pattern.reduce(0) { $0 + Cost.integer($1) }
        total += Cost.integer(seeds.count)
        for (_, phrase) in seeds { total += phrase.literalBitCost }
        total += Cost.integer(definitions.count)
        let named = max(1, definitions.count)
        let nseeds = max(1, seeds.count)
        for def in definitions {
            total += def.body.bitCost(namedCount: named, seedCount: nseeds)
        }
        return total + root.bitCost(namedCount: named, seedCount: nseeds)
    }

    /// The verification that matters for the generative half: does the derivation reproduce the
    /// score exactly?
    public func reproducesExactly(_ target: Phrase) throws -> Bool {
        try evaluate().notes == target.notes
    }

    /// The MDL judgement against a target, with the residual left at zero until the residual
    /// model is reinstated against spelled pitch.
    public func verdict(against target: Phrase) throws -> Verdict {
        let produced = try evaluate()
        let exact = produced.notes == target.notes
        return Verdict(modelBits: bitCost,
                       residualBits: exact ? 0 : .infinity,
                       literalBits: target.literalBitCost,
                       noteCount: target.count)
    }
}
