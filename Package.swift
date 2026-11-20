// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwimIO",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwimIO",
            targets: ["SwimIO"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/IO.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Path.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Readers.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Writers.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "SwimIO",
            dependencies: [
                .product(
                    name: "IO",
                    package: "IO"
                ),
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "Readers",
                    package: "Readers"
                ),
                .product(
                    name: "Writers",
                    package: "Writers"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
