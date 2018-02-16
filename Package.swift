// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "TMLRuby",
    products: [
        .library(
            name: "TMLRuby",
            targets: ["TMLRuby", "TMLRubyHelpers"])
    ],
    dependencies: [
        .package(url: "CRuby/", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "TMLRuby",
            dependencies: ["TMLRubyHelpers"]),
        .target(
            name: "TMLRubyHelpers",
            dependencies: []),
        .testTarget(
            name: "TMLRubyTests",
            dependencies: ["TMLRuby"]),
    ]
)
