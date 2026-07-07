// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Speller",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SpellerCore"),
        .executableTarget(
            name: "Speller",
            dependencies: ["SpellerCore"]
        ),
        .testTarget(
            name: "SpellerCoreTests",
            dependencies: ["SpellerCore"]
        ),
    ]
)
