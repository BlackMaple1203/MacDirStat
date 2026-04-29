// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacDirStat",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacDirStat", targets: ["MacDirStat"])
    ],
    targets: [
        .executableTarget(
            name: "MacDirStat",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MacDirStatTests",
            dependencies: ["MacDirStat"],
            path: "Tests"
        )
    ]
)
