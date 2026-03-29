// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "VoiceInput",
            targets: ["VoiceInput"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VoiceInput",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
