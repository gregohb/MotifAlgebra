//
//  MIDIImport.swift
//  MotifEngine
//
//  The boundary. MIDI numbers and ticks go in; spelled pitches and exact rational time come out.
//
//  This is the only place in the suite where information is lost, and it is worth being precise
//  about which information. Ticks are converted exactly, so no time is lost. What is lost is
//  spelling: a MIDI file records key 61 and cannot say whether the composer wrote C-sharp or
//  D-flat. `Pitch(importingMIDI:in:)` picks the canonical spelling for the supplied space, and
//  the algebra's own header is blunt that this is lossy by nature.
//
//  Which makes the `space` argument the single most consequential parameter here. Importing a
//  piece in E-flat major against the default C major spells every B-flat as A-sharp, and every
//  subsequent diatonic transposition inherits the error — invisibly, because the sounding MIDI
//  numbers stay right while the step indices go wrong. The signature therefore takes the space
//  explicitly rather than assuming one.
//
//  Estimating the space from the notes themselves is a real and solvable problem, and it is
//  MAHarmonicAnalyzer's job in AMT005. That file is not ported yet, so this one does not pretend
//  to guess: it takes the key it is given and documents what happens if the caller gets it wrong.
//

import Foundation
import MotifAlgebra

public struct MIDIImport {

    /// Everything the import produced, including what it could not do cleanly.
    public struct Result: Sendable {
        /// The upper voice, spelled and in exact time.
        public var upper: Phrase
        /// The lower voice. Empty for monophonic input.
        public var lower: Phrase
        /// Both voices together, voices tagged, for callers that want the compound melody.
        public var combined: Phrase
        /// How the voices were told apart.
        public var method: VoiceSeparator.Result.Method
        /// Anything irregular in the file itself.
        public var diagnostics: [MIDIDiagnostic]
        public var ticksPerQuarter: Int
        public var format: Int
    }

    public var space: Space
    public var separatorParameters: VoiceSeparator.Parameters

    /// - Parameter space: the space to spell against. Getting this wrong does not change what
    ///   the music sounds like, but it does change every step index the algebra works on.
    public init(space: Space = .cMajor,
                separatorParameters: VoiceSeparator.Parameters = .standard) {
        self.space = space
        self.separatorParameters = separatorParameters
    }

    // MARK: - Import

    public func callAsFunction(_ file: MIDIFile) -> Result { imported(file) }

    public func imported(_ file: MIDIFile) -> Result {
        let separator = VoiceSeparator(ticksPerQuarter: file.ticksPerQuarter,
                                       parameters: separatorParameters)
        let split = separator.separate(file.notes)

        let upper = phrase(from: split.upper, voice: 0, ticksPerQuarter: file.ticksPerQuarter)
        let lower = phrase(from: split.lower, voice: 1, ticksPerQuarter: file.ticksPerQuarter)
        let combined = Phrase(upper.notes + lower.notes, in: space)

        return Result(upper: upper,
                      lower: lower,
                      combined: combined,
                      method: split.method,
                      diagnostics: file.diagnostics,
                      ticksPerQuarter: file.ticksPerQuarter,
                      format: file.format)
    }

    public func imported(bytes: [UInt8]) throws -> Result {
        imported(try MIDIFile(bytes: bytes))
    }

    public func imported(contentsOf url: URL) throws -> Result {
        imported(try MIDIFile(contentsOf: url))
    }

    // MARK: - Conversion

    private func phrase(from raw: [RawMIDINote],
                        voice: Int,
                        ticksPerQuarter: Int) -> Phrase {
        Phrase(raw.map { note in
            Note(onset: Rational(note.onsetTicks, ticksPerQuarter),
                 duration: Rational(note.durationTicks, ticksPerQuarter),
                 pitch: Pitch(importingMIDI: note.pitch, in: space),
                 velocity: note.velocity,
                 voice: voice)
        }, in: space)
    }
}

// MARK: - Round-trip check

public extension MIDIImport {

    /// Does the imported phrase sound like the file said?
    ///
    /// Spelling is a guess, but the sounding pitch never is: whatever `Pitch` the importer chose,
    /// `midi(in:)` must return the byte that was in the file. This is the invariant that catches
    /// a wrong space silently corrupting an import — it will still pass, which is exactly the
    /// point. It separates "we spelled it unusually" from "we got the note wrong", and only the
    /// second is a bug in this layer.
    func soundsIdentical(_ result: Result, to file: MIDIFile) -> Bool {
        // The ordering must be TOTAL over everything being compared.
        //
        // An earlier version of this method sorted on (onset, midi) and left duration out. On a
        // hand-written test that is harmless; on Beethoven's Fifth it reported a mismatch for a
        // perfectly correct import. An orchestral reduction doubles the same pitch across many
        // instruments at the same instant with different durations, so the two sides were full of
        // entries that compared equal under the key but differed in the field the key ignored —
        // and `sorted` is not guaranteed stable, so the two arrays were free to order those
        // entries differently.
        //
        // This is precisely the failure Note.canonicallyPrecedes was written to prevent, restaged
        // in the checker rather than the type. The lesson generalises: a comparison key that does
        // not reach every compared field is not a comparison.
        func precedes(_ a: (Int, Rational, Rational), _ b: (Int, Rational, Rational)) -> Bool {
            if a.1 != b.1 { return a.1 < b.1 }     // onset
            if a.0 != b.0 { return a.0 < b.0 }     // sounding pitch
            return a.2 < b.2                        // duration
        }

        let imported = result.combined.notes
            .map { ($0.midi(in: space), $0.onset, $0.duration) }
            .sorted(by: precedes)

        let original = file.notes
            .map { (
                $0.pitch,
                Rational($0.onsetTicks, file.ticksPerQuarter),
                Rational($0.durationTicks, file.ticksPerQuarter)
            ) }
            .sorted(by: precedes)

        guard imported.count == original.count else { return false }
        return zip(imported, original).allSatisfy { $0 == $1 }
    }
}
