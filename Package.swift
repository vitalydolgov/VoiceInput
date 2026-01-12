// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "VoiceInput",
            targets: ["VoiceInput"]
        ),
    ],
    targets: [
        .target(
            name: "VoiceInput",
            dependencies: [],
        ),
    ]
)
