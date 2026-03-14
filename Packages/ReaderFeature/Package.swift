// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReaderFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReaderFeature", targets: ["ReaderFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
        .package(path: "../DesignSystem"),
        .package(path: "../AnnotationFeature"),
    ],
    targets: [
        .target(name: "ReaderFeature", dependencies: ["CoreDomain", "DesignSystem", "AnnotationFeature"]),
        .testTarget(name: "ReaderFeatureTests", dependencies: ["ReaderFeature"]),
    ]
)
