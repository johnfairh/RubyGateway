// swift-tools-version:4.0

//  Package.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE

import PackageDescription

let package = Package(
    name: "RubyBridge",
    products: [
        .library(
            name: "RubyBridge",
            targets: ["RubyBridge", "RubyGatewayHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnfairh/CRuby", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RubyBridge",
            dependencies: ["RubyGatewayHelpers"]),
        .target(
            name: "RubyGatewayHelpers",
            dependencies: []),
        .testTarget(
            name: "RubyBridgeTests",
            dependencies: ["RubyBridge"]),
    ]
)
