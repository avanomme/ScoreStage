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
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "DeviceLinkFeature", dependencies: ["CoreDomain", "DesignSystem"]),
        .testTarget(name: "DeviceLinkFeatureTests", dependencies: ["DeviceLinkFeature"]),
    ]
)
