// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyncFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SyncFeature", targets: ["SyncFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
    ],
    targets: [
        .target(name: "SyncFeature", dependencies: ["CoreDomain"]),
        .testTarget(name: "SyncFeatureTests", dependencies: ["SyncFeature"]),
    ]
)
