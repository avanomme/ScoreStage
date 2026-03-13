// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibraryFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LibraryFeature", targets: ["LibraryFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "LibraryFeature", dependencies: ["CoreDomain", "DesignSystem"]),
        .testTarget(name: "LibraryFeatureTests", dependencies: ["LibraryFeature"]),
    ]
)
