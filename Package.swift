// swift-tools-version:5.1.0

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
            targets: ["RubyGateway", "RubyGatewayHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnfairh/CRuby", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "RubyGateway",
            dependencies: ["RubyGatewayHelpers"]),
        .target(
            name: "RubyGatewayHelpers",
            dependencies: []),
        .testTarget(
            name: "RubyGatewayTests",
            dependencies: ["RubyGateway"]),
    ]
)
