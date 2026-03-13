// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(path: "../CoreDomain"),
    ],
    targets: [
        .target(name: "DesignSystem", dependencies: ["CoreDomain"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
