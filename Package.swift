// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMusicDL",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SwiftMusicDL",
            targets: ["SwiftMusicDL"]
        ),
        .library(
            name: "SwiftMusicDLModels",
            targets: ["SwiftMusicDLModels"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftMusicDLModels",
            path: "SwiftMusicDL/Models"
        ),
        .executableTarget(
            name: "SwiftMusicDL",
            dependencies: ["SwiftMusicDLModels"],
            path: "SwiftMusicDL",
            exclude: ["README.md", "Models"],
            resources: [
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "SwiftMusicDLModelsTests",
            dependencies: ["SwiftMusicDLModels"],
            path: "Tests/SwiftMusicDLModels"
        ),
    ]
)