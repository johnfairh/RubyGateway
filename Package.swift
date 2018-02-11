// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "TMLRuby",
    products: [
        .library(
            name: "TMLRuby",
            targets: ["TMLRuby"]),
        .executable(
            name: "TMLRubyClient",
            targets: ["TMLRubyClient"])
    ],
    dependencies: [
        .package(url: "CRuby/", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "TMLRuby",
            dependencies: []),
        .target(
            name: "TMLRubyClient",
            dependencies: ["TMLRuby"]),
        .testTarget(
            name: "TMLRubyTests",
            dependencies: ["TMLRuby"]),
    ]
)
