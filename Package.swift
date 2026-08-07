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
        .library(name: "VertexMedia", targets: ["VertexMedia"]),
        .library(name: "VertexMediaAVFoundation", targets: ["VertexMediaAVFoundation"]),
        .library(name: "VertexRender", targets: ["VertexRender"]),
        .library(name: "VertexRenderMetal", targets: ["VertexRenderMetal"]),
        .library(name: "VertexProject", targets: ["VertexProject"]),
        .library(name: "VertexProjectPersistence", targets: ["VertexProjectPersistence"]),
        .library(name: "VertexComposition", targets: ["VertexComposition"]),
        .library(name: "VertexAI", targets: ["VertexAI"])
    ],
    targets: [
        .target(name: "VertexCore"),
        .target(
            name: "VertexMedia",
            dependencies: ["VertexCore"]
        ),
        .target(
            name: "VertexMediaAVFoundation",
            dependencies: ["VertexCore", "VertexMedia"]
        ),
        .target(
            name: "VertexRender",
            dependencies: ["VertexCore", "VertexMedia"]
        ),
        .target(
            name: "VertexRenderMetal",
            dependencies: ["VertexCore", "VertexMedia", "VertexRender"],
            resources: [.process("Shaders")]
        ),
        .target(
            name: "VertexProject",
            dependencies: ["VertexCore", "VertexMedia", "VertexRender"]
        ),
        .target(
            name: "VertexProjectPersistence",
            dependencies: ["VertexCore", "VertexMedia", "VertexProject"]
        ),
        .target(
            name: "VertexComposition",
            dependencies: ["VertexCore", "VertexMedia", "VertexProject", "VertexRender"]
        ),
        .target(
            name: "VertexAI",
            dependencies: ["VertexCore"]
        ),
        .testTarget(
            name: "VertexCoreTests",
            dependencies: ["VertexCore"]
        ),
        .testTarget(
            name: "VertexMediaTests",
            dependencies: ["VertexMedia", "VertexCore"]
        ),
        .testTarget(
            name: "VertexRenderTests",
            dependencies: ["VertexRender", "VertexMedia", "VertexCore"]
        ),
        .testTarget(
            name: "VertexRenderMetalTests",
            dependencies: [
                "VertexRenderMetal",
                "VertexRender",
                "VertexComposition",
                "VertexProject",
                "VertexMedia",
                "VertexCore"
            ]
        ),
        .testTarget(
            name: "VertexProjectTests",
            dependencies: ["VertexProject", "VertexCore", "VertexMedia", "VertexRender"]
        ),
        .testTarget(
            name: "VertexProjectPersistenceTests",
            dependencies: ["VertexProjectPersistence", "VertexProject", "VertexCore", "VertexMedia", "VertexComposition", "VertexRender", "VertexRenderMetal"]
        ),
        .testTarget(
            name: "VertexCompositionTests",
            dependencies: ["VertexComposition", "VertexProject", "VertexRender", "VertexMedia", "VertexCore"]
        ),
        .testTarget(
            name: "VertexAITests",
            dependencies: ["VertexAI", "VertexCore"]
        )
    ]
)
