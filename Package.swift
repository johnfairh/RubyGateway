// swift-tools-version:5.4.0

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
        .package(url: "https://github.com/johnfairh/CRuby", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "RubyGateway",
            dependencies: ["RubyGatewayHelpers", "CRuby"]),
        .target(
            name: "RubyGatewayHelpers",
            dependencies: ["CRuby"]),
        .testTarget(
            name: "RubyGatewayTests",
            dependencies: ["RubyGateway"],
            exclude: ["Fixtures"])
    ]
)
