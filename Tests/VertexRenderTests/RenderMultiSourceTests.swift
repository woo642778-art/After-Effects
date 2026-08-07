import Foundation
import Testing
import VertexCore
import VertexMedia
@testable import VertexRender

private func renderID(_ suffix: String) -> VertexID {
    VertexID(rawValue: "64000000-0000-0000-0000-\(suffix)")
}

private func renderImage(_ byte: UInt8) throws -> PortableImage {
    try PortableImage(
        data: Data([byte]),
        format: .png,
        pixelSize: VertexSize(width: 1, height: 1)
    )
}

@Test("Composite dependency order remains backdrop then source")
func compositeDependencyOrderIsSemantic() throws {
    let backdropID = renderID("000000000001")
    let sourceID = renderID("000000000002")
    let compositeID = renderID("000000000003")
    let outputID = renderID("000000000004")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try renderImage(2))),
        RenderNode(id: backdropID, dependencies: [], kind: .solidColor(.transparent)),
        RenderNode(id: compositeID, dependencies: [backdropID, sourceID], kind: .composite(.multiply)),
        RenderNode(id: outputID, dependencies: [compositeID], kind: .output)
    ])

    let plan = try graph.evaluationPlan()
    let composite = try #require(plan.orderedNodes.first(where: { $0.id == compositeID }))
    #expect(composite.dependencies == [backdropID, sourceID])
    #expect(plan.outputNodeID == outputID)
    #expect(plan.consumerCounts[backdropID] == 1)
    #expect(plan.consumerCounts[sourceID] == 1)
}

@Test("Disconnected render nodes are rejected")
func disconnectedNodesAreRejected() throws {
    let used = renderID("000000000011")
    let disconnected = renderID("000000000012")
    let output = renderID("000000000013")
    let graph = RenderGraph(nodes: [
        RenderNode(id: used, dependencies: [], kind: .solidColor(.transparent)),
        RenderNode(id: disconnected, dependencies: [], kind: .source(try renderImage(3))),
        RenderNode(id: output, dependencies: [used], kind: .output)
    ])
    #expect(throws: RenderError.self) { try graph.evaluationPlan() }
}

@Test("Multiple sources, local operations, adjustment, and composite validate")
func multiSourceGraphValidates() throws {
    let background = renderID("000000000021")
    let image = renderID("000000000022")
    let operation = renderID("000000000023")
    let composite = renderID("000000000024")
    let adjustment = renderID("000000000025")
    let output = renderID("000000000026")
    let graph = RenderGraph(nodes: [
        RenderNode(id: background, dependencies: [], kind: .solidColor(.black)),
        RenderNode(id: image, dependencies: [], kind: .source(try renderImage(4))),
        RenderNode(
            id: operation,
            dependencies: [image],
            kind: .operations([.transform2D(.identity), .opacity(0.5)])
        ),
        RenderNode(id: composite, dependencies: [background, operation], kind: .composite(.screen)),
        RenderNode(id: adjustment, dependencies: [composite], kind: .adjustment([.exposure(stops: 1)], mix: 0.25)),
        RenderNode(id: output, dependencies: [adjustment], kind: .output)
    ])
    #expect(try graph.evaluationPlan().orderedNodes.count == 6)
}

@Test("Render cache context changes cache identity")
func renderCacheContextIsSemantic() throws {
    let source = renderID("000000000031")
    let output = renderID("000000000032")
    let graph = RenderGraph(nodes: [
        RenderNode(id: source, dependencies: [], kind: .solidColor(.black)),
        RenderNode(id: output, dependencies: [source], kind: .output)
    ])
    let specification = try RenderOutputSpecification(width: 16, height: 16)
    let first = try RenderRequest(
        graph: graph,
        time: .zero,
        output: specification,
        context: RenderCacheContext(compositionID: renderID("000000000040"), projectRevision: 1, compilerVersion: 1)
    )
    let changed = try RenderRequest(
        graph: graph,
        time: .zero,
        output: specification,
        context: RenderCacheContext(compositionID: renderID("000000000040"), projectRevision: 2, compilerVersion: 1)
    )
    #expect(first.cacheKey != changed.cacheKey)
}
