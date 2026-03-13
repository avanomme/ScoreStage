// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SetlistFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SetlistFeature", targets: ["SetlistFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "SetlistFeature", dependencies: ["CoreDomain", "DesignSystem"]),
        .testTarget(name: "SetlistFeatureTests", dependencies: ["SetlistFeature"]),
    ]
)
