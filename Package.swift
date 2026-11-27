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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
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
