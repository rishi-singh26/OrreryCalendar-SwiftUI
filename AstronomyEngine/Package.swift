// swift-tools-version:5.9
import PackageDescription

// Wraps the vendored Astronomy Engine C library (cosinekitty/astronomy, tag v2.1.19,
// MIT licensed — see LICENSE) in a thin, idiomatic Swift API.
let package = Package(
    name: "AstronomyEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "AstronomyEngineSwift",
            targets: ["AstronomyEngineSwift"]
        ),
    ],
    targets: [
        .target(
            name: "CAstronomyEngine",
            path: "Sources/CAstronomyEngine",
            publicHeadersPath: "include"
        ),
        .target(
            name: "AstronomyEngineSwift",
            dependencies: ["CAstronomyEngine"],
            path: "Sources/AstronomyEngineSwift"
        ),
    ]
)
