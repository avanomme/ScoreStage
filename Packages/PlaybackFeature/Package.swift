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
        .package(path: "../NotationFeature"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "PlaybackFeature", dependencies: ["CoreDomain", "NotationFeature", "DesignSystem"]),
        .testTarget(name: "PlaybackFeatureTests", dependencies: ["PlaybackFeature"]),
    ]
)
