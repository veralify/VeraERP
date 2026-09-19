// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoneyManagerCore",
    // macOS is supported so the payoff engine's tests run with `swift test` in
    // seconds, without booting a simulator. Nothing here may import UIKit.
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "MoneyManagerCore", targets: ["MoneyManagerCore"])
    ],
    targets: [
        .target(name: "MoneyManagerCore"),
        .testTarget(
            name: "MoneyManagerCoreTests",
            dependencies: ["MoneyManagerCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
