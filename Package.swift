// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsing",
    products: [
        .library(
            name: "Parsing",
            targets: ["Parsing"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "Parsing"),
        .testTarget(
            name: "ParsingTests",
            dependencies: ["Parsing"]),
    ]
)
