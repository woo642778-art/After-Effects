// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VertexCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VertexCore", targets: ["VertexCore"])
    ],
    targets: [
        .target(name: "VertexCore"),
        .testTarget(name: "VertexCoreTests", dependencies: ["VertexCore"])
    ]
)
