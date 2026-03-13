// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaybackFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlaybackFeature", targets: ["PlaybackFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
    ],
    targets: [
        .target(name: "PlaybackFeature", dependencies: ["CoreDomain"]),
        .testTarget(name: "PlaybackFeatureTests", dependencies: ["PlaybackFeature"]),
    ]
)
