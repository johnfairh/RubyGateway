// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "RubyBridge",
    products: [
        .library(
            name: "RubyBridge",
            targets: ["RubyBridge", "RubyBridgeHelpers"])
    ],
    dependencies: [
        .package(url: "CRuby/", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "RubyBridge",
            dependencies: ["RubyBridgeHelpers"]),
        .target(
            name: "RubyBridgeHelpers",
            dependencies: []),
        .testTarget(
            name: "RubyBridgeTests",
            dependencies: ["RubyBridge"]),
    ]
)
