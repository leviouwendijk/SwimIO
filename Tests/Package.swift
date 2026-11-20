// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwimIOTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "swimiotest",
            targets: ["SwimIOTestFlows"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/IO.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Writers.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "SwimIOTestFlows",
            dependencies: [
                .product(name: "SwimIO", package: "SwimIO"),
                .product(
                    name: "IO",
                    package: "IO"
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
