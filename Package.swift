// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftStoreFlow",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftStoreFlow",
            targets: ["SwiftStoreFlow"]
        )
    ],
    targets: [
        .target(
            name: "SwiftStoreFlow",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "SwiftStoreFlowTests",
            dependencies: ["SwiftStoreFlow"]
        )
    ]
)
