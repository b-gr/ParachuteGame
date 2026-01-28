// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TubeDiver",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TubeDiverCore", targets: ["TubeDiverCore"]),
        .executable(name: "TubeDiverMacApp", targets: ["TubeDiverMacApp"]),
    ],
    targets: [
        .target(
            name: "TubeDiverCore",
            dependencies: []
        ),
        .executableTarget(
            name: "TubeDiverMacApp",
            dependencies: ["TubeDiverCore"]
        ),
    ]
)
