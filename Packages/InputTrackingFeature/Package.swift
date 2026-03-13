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
    ],
    targets: [
        .target(name: "InputTrackingFeature", dependencies: ["CoreDomain"]),
        .testTarget(name: "InputTrackingFeatureTests", dependencies: ["InputTrackingFeature"]),
    ]
)
