// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MoodleNativeShared",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MoodleNativeCore",
            targets: ["MoodleNativeCore"]
        ),
        .library(
            name: "MoodleNativeNetworking",
            targets: ["MoodleNativeNetworking"]
        ),
        .library(
            name: "MoodleNativeFeatures",
            targets: ["MoodleNativeFeatures"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-http-types", from: "1.5.1"),
    ],
    targets: [
        .target(
            name: "MoodleNativeCore",
            path: "Sources/Core"
        ),
        .target(
            name: "MoodleNativeNetworking",
            dependencies: [
                "MoodleNativeCore",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/Networking"
        ),
        .target(
            name: "MoodleNativeFeatures",
            dependencies: ["MoodleNativeCore", "MoodleNativeNetworking"],
            path: "Sources/Features"
        ),
        .testTarget(
            name: "MoodleNativeCoreTests",
            dependencies: ["MoodleNativeCore"],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "MoodleNativeNetworkingTests",
            dependencies: ["MoodleNativeCore", "MoodleNativeNetworking"],
            path: "Tests/NetworkingTests"
        ),
        .testTarget(
            name: "MoodleNativeFeaturesTests",
            dependencies: ["MoodleNativeCore", "MoodleNativeNetworking", "MoodleNativeFeatures"],
            path: "Tests/FeaturesTests"
        ),
    ]
)
