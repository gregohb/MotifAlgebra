//
//  ContentView.swift
//  MotifSuite
//
//  Still a placeholder for the real motif browser, but now an audible one.
//
//  It takes a seed motif, applies each transform constructor, and reports what the algebra says
//  about the result — sounding pitches, step-interval vector, similarity class against the seed,
//  and the MDL bit-cost of the transform itself. Each row plays.
//
//  Hearing the rows is the point of wiring playback in this early. `retrograde ∘ T+4` having a
//  bit-cost of 9.2 is a claim about an encoding; whether it sounds like the seed is a claim about
//  music, and only one of those can be checked by reading the table.
//

import SwiftUI
import MotifAlgebra
import MotifEngine

struct ContentView: View {

    /// Step 35 is middle C — the lattice is absolute and zero-based.
    private static let middleC = 35

    /// What the transforms are applied to. The two real scores are hand-encoded in MotifEngine;
    /// playing them is how their encoding gets checked.
    private enum Source: String, CaseIterable, Identifiable {
        case scale = "Four-note figure"
        case furElise = "Für Elise (opening)"
        case fifth = "Symphony No. 5 (motto)"

        var id: String { rawValue }

        var phrase: Phrase {
            switch self {
            case .scale:
                return Phrase([
                    Note(Rational(0), .quarter, ContentView.middleC),
                    Note(.quarter, .quarter, ContentView.middleC + 2),
                    Note(.half, .quarter, ContentView.middleC + 4),
                    Note(Rational(3, 4), .quarter, ContentView.middleC + 3)
                ], in: .cMajor)
            case .furElise:
                return Scores.furEliseMelody
            case .fifth:
                return Scores.fifthSymphonyMotto
            }
        }

        /// Für Elise wants a slower reading than a bare figure does.
        var suggestedTempo: Tempo {
            switch self {
            case .scale: return Tempo(bpm: 100)
            case .furElise: return Tempo(bpm: 60)
            case .fifth: return Tempo(bpm: 108)
            }
        }
    }

    @StateObject private var player = Player()
    @State private var source: Source = .scale
    @State private var tempo = Tempo(bpm: 100)
    @State private var nowPlaying: String?

    private var seed: Phrase { source.phrase }

    private var rows: [Row] {
        // Invert about the seed's own first degree, so the image stays in register whatever
        // the source. Inverting Für Elise about middle C would put it under the floor.
        let anchor = seed.notes.first?.pitch.step ?? Self.middleC

        let catalogue: [(String, Transform)] = [
            ("identity", .identity),
            ("T+2", .translate(2)),
            ("invert about first note", .invert(about: anchor)),
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
            table
            Divider()
            transport
        }
        .onDisappear { player.stop() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("MotifSuite")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Seed", selection: $source) {
                    ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: source) { _ in
                    player.stop()
                    nowPlaying = nil
                    tempo = source.suggestedTempo
                }
            }
            Text("\(seed.count) notes in \(seed.space.name), spanning "
                 + "\(seed.span.description) quarter notes")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospaced()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Table

    private var table: some View {
        Table(rows) {
            TableColumn("") { row in
                Button {
                    play(row)
                } label: {
                    Image(systemName: nowPlaying == row.name && player.state == .playing
                          ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Play \(row.name)")
            }
            .width(28)

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

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 16) {
            Button {
                player.stop()
                nowPlaying = nil
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(player.state == .stopped)

            Divider().frame(height: 16)

            Text("Tempo")
                .foregroundStyle(.secondary)
            Slider(value: Binding(get: { tempo.bpm },
                                  set: { tempo = Tempo(bpm: $0) }),
                   in: Tempo.minimumBPM ... Tempo.maximumBPM)
                .frame(width: 160)
            Text(tempo.description)
                .monospaced()
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)

            Spacer()

            if let error = player.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .help(error)
            } else if player.state == .playing, let nowPlaying {
                Text("\(nowPlaying) — beat \(String(format: "%.1f", player.positionBeats))")
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func play(_ row: Row) {
        if nowPlaying == row.name && player.state == .playing {
            player.stop()
            nowPlaying = nil
            return
        }
        nowPlaying = row.name
        player.play(row.image, tempo: tempo)
    }

    // MARK: - Row

    private struct Row: Identifiable {
        let name: String
        let transform: Transform
        let image: Phrase
        let similarity: Similarity

        var id: String { name }

        /// Truncated — Für Elise's opening is 37 notes and would push every other column off
        /// the window.
        var pitchNames: String {
            let names = image.notes.map { $0.pitch.name(in: image.space) }
            return names.count <= 10
                ? names.joined(separator: " ")
                : names.prefix(10).joined(separator: " ") + " … (\(names.count))"
        }

        var intervals: String {
            let steps = image.stepIntervals.map(String.init)
            return steps.count <= 10
                ? steps.joined(separator: " ")
                : steps.prefix(10).joined(separator: " ") + " …"
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 860, height: 420)
}
