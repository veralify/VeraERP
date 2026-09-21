// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VeralifyCore",
    // macOS is supported so the payoff engine's tests run with `swift test` in
    // seconds, without booting a simulator. Nothing here may import UIKit.
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "VeralifyCore", targets: ["VeralifyCore"])
    ],
    targets: [
        .target(name: "VeralifyCore"),
        .testTarget(
            name: "VeralifyCoreTests",
            dependencies: ["VeralifyCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
