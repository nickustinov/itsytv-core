// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "itsytv-core",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ItsytvCore", targets: ["ItsytvCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/adam-fowler/swift-srp.git", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "ItsytvCore",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "SRP", package: "swift-srp"),
            ]
        ),
        .testTarget(
            name: "ItsytvCoreTests",
            dependencies: ["ItsytvCore"]
        ),
    ]
)
