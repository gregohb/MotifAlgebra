# MotifSuite

A motif algebra and the macOS app built on top of it.

## Layout

```
MotifSuite.xcodeproj      macOS app target — SwiftUI, thin by design
App/                      app sources (presentation only)
Packages/MotifSuite/      the SwiftPM package: the mathematics
  Sources/MotifAlgebra/   pure. Foundation and nothing else
  Tests/                  the law tests
```

The layering is the point. `MotifAlgebra` imports nothing but Foundation, so its tests run
under `swift test` with no app launched and no UI types in scope. A change to a view cannot
break the mathematics, because the mathematics cannot see it.

`MotifEngine` sits on top of the algebra and holds everything that touches the outside
world — files, voices, sound:

| | |
| --- | --- |
| `MIDIFile` | Standard MIDI File parsing; integer ticks, never divided early |
| `MIDIImport` | the boundary — ticks to `Rational`, MIDI numbers to spelled `Pitch` |
| `VoiceSeparator` | two-voice separation, by channel or greedily with look-ahead |
| `Tempo` | BPM, markings, and note values as exact fractions |
| `PlaybackSchedule` | what sounds when, computed ahead of time and independently per event |
| `PlaybackEngine` | `AVAudioUnitSampler` — the only part that needs hardware |
| `Player` | transport: absolute deadlines, cancellable, no busy loop |

Still to come:

- harmonic analysis — key and chord estimation, ported from AMT005's `MAHarmonicAnalyzer`.
  Until it exists, `MIDIImport` takes the `Space` to spell against and does not guess.
- `MotifApp` — the real interface: motif selection, sibling catalogue, DNA panel, compose mode

## Building and testing

The algebra, with no Xcode involved:

```sh
cd Packages/MotifSuite
swift test
```

The app:

```sh
xcodebuild -project MotifSuite.xcodeproj -scheme MotifSuite build
```

or open `MotifSuite.xcodeproj` and press ⌘R. Opening `Packages/MotifSuite/Package.swift`
directly in Xcode also works, and is the faster loop when only the algebra is in play.

The app target consumes the package as a **local** package reference, so edits to
`MotifAlgebra` are picked up by the next app build with no version bump or resolution step.

## Design notes

The substantive decisions are documented in the file headers, which are worth reading before
changing anything:

| File | The decision |
| --- | --- |
| `Rational.swift` | musical time is rational, not floating-point |
| `Pitch.swift` | pitch is *spelled* and stored — C♯ and D♭ stay distinct |
| `Maps.swift` | two constructors per axis, not a flat enum of pre-composed names |
| `Transform.swift` | transformations compose; pitch and time maps commute |
| `Similarity.swift` | the sign-vector classes, and why plain `similar` is chance-prone |
| `BitCost.swift` | exact Elias-gamma coding, no floating-point `log2` |
| `MIDIFile.swift` | accumulate ticks, divide once — a MIDI file's time base is already rational |
| `PlaybackSchedule.swift` | why a playhead must be read from a clock, never accumulated |

## Status

74 tests, all passing — 26 algebra, 14 MIDI import, 9 voice separation, 22 scheduling,
3 audio. The app plays: each transform in the table can be heard against the seed.

Not yet done: harmonic analysis, and the real interface.
