// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SiroNav",
    defaultLocalization: "ar",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SiroNav",
            targets: ["SiroNav"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SiroNav",
            dependencies: [],
            path: "Sources/SiroNav",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SiroNavTests",
            dependencies: ["SiroNav"],
            path: "Tests/SiroNavTests"
        )
    ]
)
