// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkTraceKit",
    defaultLocalization: "en",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "WTCore", targets: ["WTCore"]),
        .library(name: "WTStorage", targets: ["WTStorage"]),
        .library(name: "WTObservation", targets: ["WTObservation"]),
        .library(name: "WTNormalization", targets: ["WTNormalization"]),
        .library(name: "WTSession", targets: ["WTSession"]),
        .library(name: "WTReporting", targets: ["WTReporting"]),
        .library(name: "WTAI", targets: ["WTAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        // Layer 0: pure domain model. No dependencies.
        .target(name: "WTCore"),

        // Persistence. Isolates GRDB (and future SQLCipher) from the rest of the app.
        .target(
            name: "WTStorage",
            dependencies: [
                "WTCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),

        // Activity capture (app / window title / idle).
        .target(name: "WTObservation", dependencies: ["WTCore"]),

        // Privacy masking, normalization and dedup. Runs BEFORE storage.
        .target(name: "WTNormalization", dependencies: ["WTCore"]),

        // Manual timer state machine + session engine.
        .target(name: "WTSession", dependencies: ["WTCore", "WTStorage"]),

        // Deterministic report / export builders (bilingual).
        .target(name: "WTReporting", dependencies: ["WTCore", "WTStorage"]),

        // AI seam: protocols + no-op stubs. No LLM integration yet.
        .target(name: "WTAI", dependencies: ["WTCore"]),

        .testTarget(name: "WTCoreTests", dependencies: ["WTCore"]),
        .testTarget(name: "WTStorageTests", dependencies: ["WTStorage"]),
        .testTarget(name: "WTSessionTests", dependencies: ["WTSession", "WTStorage"]),
        .testTarget(name: "WTNormalizationTests", dependencies: ["WTNormalization", "WTCore"]),
        .testTarget(name: "WTReportingTests", dependencies: ["WTReporting", "WTStorage", "WTCore"]),
    ],
    swiftLanguageModes: [.v5]
)
