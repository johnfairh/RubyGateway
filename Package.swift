// swift-tools-version:4.0

//  Package.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE

import PackageDescription

let package = Package(
    name: "RubyBridge",
    products: [
        .library(
            name: "RubyBridge",
            targets: ["RubyBridge", "RubyBridgeHelpers"])
    ],
    dependencies: [
        .package(url: "CRuby/", from: "1.0.0"),
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
