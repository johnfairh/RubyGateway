// swift-tools-version:6.0

//  Package.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE

import PackageDescription

let package = Package(
    name: "RubyGateway",
    products: [
        .library(
            name: "RubyGateway",
            targets: ["RubyGateway", "RubyGatewayHelpers"]),
        .executable(
            name: "RubyThreadSample",
            targets: ["RubyThreadSample"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnfairh/CRuby", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "RubyGateway",
            dependencies: ["RubyGatewayHelpers", "CRuby"],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "RubyGatewayHelpers",
            dependencies: ["CRuby"]),
        .testTarget(
            name: "RubyGatewayTests",
            dependencies: ["RubyGateway"],
            exclude: ["Fixtures"]),
        .executableTarget(
            name: "RubyThreadSample",
            dependencies: ["RubyGateway"])
    ]
)
