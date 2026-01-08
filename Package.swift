// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tasks.mac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Tasks.mac", targets: ["Tasks.mac"]),
    ],
    targets: [
        .executableTarget(name: "Tasks.mac", path: "Sources/Tasks.mac"),
        .executableTarget(name: "AcceptanceRunner"),
        .testTarget(
            name: "AcceptanceTests",
            dependencies: ["Tasks.mac"]
        ),
    ]
)
