// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceLinkFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DeviceLinkFeature", targets: ["DeviceLinkFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
    ],
    targets: [
        .target(name: "DeviceLinkFeature", dependencies: ["CoreDomain"]),
        .testTarget(name: "DeviceLinkFeatureTests", dependencies: ["DeviceLinkFeature"]),
    ]
)
