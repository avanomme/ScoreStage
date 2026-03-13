// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotationFeature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NotationFeature", targets: ["NotationFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
    ],
    targets: [
        .target(name: "NotationFeature", dependencies: ["CoreDomain"]),
        .testTarget(name: "NotationFeatureTests", dependencies: ["NotationFeature"]),
    ]
)
