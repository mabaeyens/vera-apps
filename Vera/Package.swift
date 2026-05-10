// swift-tools-version: 6.0
// Package.swift declares SPM dependencies only.
// Actual targets live in Vera.xcodeproj.
// Add this package via: File > Add Package Dependencies > Add Local…

import PackageDescription

let package = Package(
    name: "Vera",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    dependencies: [
        .package(
            url: "https://github.com/gonzalezreal/swift-markdown-ui",
            .upToNextMajor(from: "2.4.0")
        ),
        .package(
            url: "https://github.com/raspu/Highlightr",
            .upToNextMajor(from: "2.2.0")
        ),
    ],
    targets: [
        // Placeholder — actual targets are in the Xcode project.
        .target(
            name: "VeShared",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Highlightr", package: "Highlightr"),
            ],
            path: "Vera/Shared"
        ),
    ]
)
