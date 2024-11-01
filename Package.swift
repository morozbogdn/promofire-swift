// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "promofire-swift",
    platforms: [
            .iOS(.v13),
            .macOS(.v10_15),
            .tvOS(.v13),
            .watchOS(.v6)
        ],
    products: [
        .library(
            name: "promofire-swift",
            targets: ["promofire-swift"]),
    ],
    targets: [
        .target(
            name: "promofire-swift"),
        .testTarget(
            name: "promofire-swiftTests",
            dependencies: ["promofire-swift"]),
    ]
)
