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
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "6.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "11.0.0"),
    ],
    targets: [
        .target(name: "TasksCore", path: "Sources/TasksCore"),
        .executableTarget(
            name: "Tasks.mac",
            dependencies: ["TasksCore"],
            path: "Sources/Tasks.mac"
        ),
        .testTarget(
            name: "Tasks.mac.ut",
            dependencies: [
                "TasksCore",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "Tasks.mac.at",
            dependencies: [
                "Tasks.mac",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/AcceptanceTests"
        ),
    ]
)
