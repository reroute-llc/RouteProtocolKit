// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RouteProtocolKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RouteProtocolKit",
            targets: ["RouteProtocolKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "RouteProtocolKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/RouteProtocolKit"
        ),
        .testTarget(
            name: "RouteProtocolKitTests",
            dependencies: ["RouteProtocolKit"],
            path: "Tests/RouteProtocolKitTests"
        ),
    ]
)
