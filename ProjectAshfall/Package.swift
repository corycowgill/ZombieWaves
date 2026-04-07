// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ProjectAshfall",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProjectAshfall",
            targets: ["ProjectAshfall"]
        ),
    ],
    targets: [
        .target(
            name: "ProjectAshfall",
            path: "ProjectAshfall",
            resources: [
                .process("Assets/Data"),
                .process("Info.plist")
            ]
        ),
        .testTarget(
            name: "ProjectAshfallTests",
            dependencies: ["ProjectAshfall"],
            path: "Tests"
        ),
    ]
)
