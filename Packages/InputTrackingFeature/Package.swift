// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputTrackingFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InputTrackingFeature", targets: ["InputTrackingFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "InputTrackingFeature", dependencies: ["CoreDomain", "DesignSystem"]),
        .testTarget(name: "InputTrackingFeatureTests", dependencies: ["InputTrackingFeature"]),
    ]
)
