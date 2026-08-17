// swift-tools-version: 5.9
//
//  MotifSuite
//
//  Three modules, deliberately layered:
//
//    MotifAlgebra   pure. No dependencies beyond Foundation. Unit-testable with `swift test`
//                   without a running app, which the AMT005 arrangement made impossible.
//    MotifEngine    voice separation, MIDI I/O, harmonic analysis, playback. (to come)
//    MotifApp       SwiftUI. Motif selection, sibling catalogue, DNA panel, compose mode.
//
//  The layering is the point. In AMT005 the algebra's own self-test imported the app's model
//  layer, so a change to a UI-facing enum could break the mathematics. Here that cannot happen:
//  MotifAlgebra has nothing to import.
//

import PackageDescription

let package = Package(
    name: "MotifSuite",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "MotifAlgebra", targets: ["MotifAlgebra"]),
        .library(name: "MotifEngine", targets: ["MotifEngine"])
    ],
    targets: [
        .target(
            name: "MotifAlgebra",
            path: "Sources/MotifAlgebra"
        ),
        .target(
            name: "MotifEngine",
            dependencies: ["MotifAlgebra"],
            path: "Sources/MotifEngine"
        ),
        .testTarget(
            name: "MotifAlgebraTests",
            dependencies: ["MotifAlgebra"],
            path: "Tests/MotifAlgebraTests"
        ),
        .testTarget(
            name: "MotifEngineTests",
            dependencies: ["MotifEngine"],
            path: "Tests/MotifEngineTests"
        )
    ]
)
