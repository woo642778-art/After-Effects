// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vertex",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VertexCore", targets: ["VertexCore"]),
        .library(name: "VertexMedia", targets: ["VertexMedia"])
    ],
    targets: [
        .target(name: "VertexCore"),
        .target(
            name: "VertexMedia",
            dependencies: ["VertexCore"]
        ),
        .testTarget(
            name: "VertexCoreTests",
            dependencies: ["VertexCore"]
        ),
        .testTarget(
            name: "VertexMediaTests",
            dependencies: ["VertexMedia", "VertexCore"]
        )
    ]
)
