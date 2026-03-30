// swift-tools-version: 5.10
// Copyright (C) 2024 zpzlabs (zpzlabs.com)
// SPDX-License-Identifier: AGPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "MaxMindDB",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MaxMindDB",
            targets: ["MaxMindDB"]
        ),
        .executable(
            name: "MaxMindDBBenchmark",
            targets: ["MaxMindDBBenchmark"]
        ),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MaxMindDB",
            dependencies: [],
            path: "Sources/MaxMindDB"
        ),
        .testTarget(
            name: "MaxMindDBTests",
            dependencies: ["MaxMindDB"],
            path: "Tests"),
        .executableTarget(
            name: "MaxMindDBBenchmark",
            dependencies: ["MaxMindDB"],
            path: "Benchmarks/MaxMindDBBenchmark"),
    ]
)
