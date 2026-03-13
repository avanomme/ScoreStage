// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnnotationFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AnnotationFeature", targets: ["AnnotationFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "AnnotationFeature", dependencies: ["CoreDomain", "DesignSystem"]),
        .testTarget(name: "AnnotationFeatureTests", dependencies: ["AnnotationFeature"]),
    ]
)
