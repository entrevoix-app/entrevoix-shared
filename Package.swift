// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EntrevoixShared",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "EntrevoixCore", targets: ["EntrevoixCore"]),
        .library(name: "EntrevoixOpenAIAdapters", targets: ["EntrevoixOpenAIAdapters"]),
        .library(name: "EntrevoixCloudKitAdapters", targets: ["EntrevoixCloudKitAdapters"])
    ],
    targets: [
        .target(name: "EntrevoixCore"),
        .target(name: "EntrevoixOpenAIAdapters", dependencies: ["EntrevoixCore"]),
        .target(name: "EntrevoixCloudKitAdapters", dependencies: ["EntrevoixCore"]),
        .testTarget(name: "EntrevoixCoreTests", dependencies: ["EntrevoixCore"])
    ]
)
