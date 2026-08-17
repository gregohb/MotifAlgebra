//
//  ContentView.swift
//  MotifSuite
//
//  A placeholder, but not an empty one.
//
//  It takes a seed motif, applies each of the four Transform constructors, and reports what the
//  algebra says about the result — the sounding pitches, the step-interval vector, the similarity
//  class against the seed, and the MDL bit-cost of the transform itself. If this window renders
//  with plausible numbers in it, the package is correctly linked and the module boundary holds.
//
//  Replace it with the real motif browser; the point of the file is that there is something to
//  replace.
//

import SwiftUI
import MotifAlgebra

struct ContentView: View {

    /// A seed motif: four notes rising through the C major lattice.
    private let seed = Phrase([
        Note(Rational(0), .quarter, 0),
        Note(.quarter, .quarter, 2),
        Note(.half, .quarter, 4),
        Note(Rational(3, 4), .quarter, 3)
    ], in: .cMajor)

    private var rows: [Row] {
        let catalogue: [(String, Transform)] = [
            ("identity", .identity),
            ("T+2", .translate(2)),
            ("invert about C", .invert(about: 0)),
            ("retrograde", .retrograde),
            ("augment ×2", .augment(Rational(2))),
            ("retrograde ∘ T+4", Transform.retrograde.then(.translate(4)))
        ]
        return catalogue.map { name, transform in
            let image = transform.apply(to: seed)
            return Row(name: name,
                       transform: transform,
                       image: image,
                       similarity: Similarity.classify(reference: seed, candidate: image))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Table(rows) {
                TableColumn("Transform") { row in
                    Text(row.name).fontWeight(.medium)
                }
                TableColumn("Notation") { row in
                    Text(row.transform.description).monospaced()
                }
                TableColumn("Pitches") { row in
                    Text(row.pitchNames).monospaced()
                }
                TableColumn("Intervals") { row in
                    Text(row.intervals).monospaced()
                }
                TableColumn("Similarity") { row in
                    Text(row.similarity.description)
                        .foregroundStyle(row.similarity.isFalsifiableOnItsOwn
                                         ? Color.primary : Color.secondary)
                }
                TableColumn("Bits") { row in
                    Text(String(format: "%.1f", row.transform.bitCost)).monospaced()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MotifSuite")
                .font(.title2.weight(.semibold))
            Text("Seed \(seed.description) in \(seed.space.name) — "
                 + "\(seed.count) notes spanning \(seed.span.description)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospaced()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private struct Row: Identifiable {
        let name: String
        let transform: Transform
        let image: Phrase
        let similarity: Similarity

        var id: String { name }

        var pitchNames: String {
            image.notes.map { $0.pitch.name(in: image.space) }.joined(separator: " ")
        }

        var intervals: String {
            image.stepIntervals.map(String.init).joined(separator: " ")
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 720, height: 400)
}
