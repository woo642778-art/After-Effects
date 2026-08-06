import Foundation
import Testing
import VertexCore
import VertexMedia
@testable import VertexRender

private func fixedID(_ suffix: String) -> VertexID {
    VertexID(rawValue: "00000000-0000-0000-0000-\(suffix)")
}

private func fixtureImage(byte: UInt8 = 1) throws -> PortableImage {
    try PortableImage(
        data: Data([byte]),
        format: .png,
        pixelSize: VertexSize(width: 4, height: 4)
    )
}

private func validGraph(exposure: Double = 0) throws -> RenderGraph {
    let sourceID = fixedID("000000000001")
    let operationID = fixedID("000000000002")
    let outputID = fixedID("000000000003")
    return RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try fixtureImage())),
        RenderNode(
            id: operationID,
            dependencies: [sourceID],
            kind: .operations([
                .transform(scale: 1, translationX: 0, translationY: 0),
                .exposure(stops: exposure),
                .saturation(1),
                .invert(false),
                .opacity(1)
            ])
        ),
        RenderNode(id: outputID, dependencies: [operationID], kind: .output)
    ])
}

@Test("A source operation output graph validates deterministically")
func validGraphOrdersDependencies() throws {
    let nodes = try validGraph().validatedNodes()
    #expect(nodes.count == 3)
    #expect(nodes.first?.id == fixedID("000000000001"))
    #expect(nodes.last?.id == fixedID("000000000003"))
}

@Test("A missing dependency is rejected with its stable identifier")
func missingDependency() throws {
    let sourceID = fixedID("000000000001")
    let missingID = fixedID("000000000099")
    let outputID = fixedID("000000000003")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try fixtureImage())),
        RenderNode(id: outputID, dependencies: [missingID], kind: .output)
    ])

    #expect(throws: RenderError.missingNode(missingID.rawValue)) {
        _ = try graph.validatedNodes()
    }
}

@Test("Cycles fail before backend execution")
func cycleDetection() throws {
    let sourceID = fixedID("000000000001")
    let firstID = fixedID("000000000002")
    let secondID = fixedID("000000000003")
    let outputID = fixedID("000000000004")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try fixtureImage())),
        RenderNode(id: firstID, dependencies: [secondID], kind: .operations([.opacity(1)])),
        RenderNode(id: secondID, dependencies: [firstID], kind: .operations([.exposure(stops: 0)])),
        RenderNode(id: outputID, dependencies: [firstID], kind: .output)
    ])

    #expect(throws: RenderError.self) {
        _ = try graph.validatedNodes()
    }
}

@Test("Output dimensions and operation values are validated")
func invalidValues() throws {
    #expect(throws: RenderError.self) {
        _ = try RenderOutputSpecification(width: 0, height: 1080)
    }

    let sourceID = fixedID("000000000001")
    let operationID = fixedID("000000000002")
    let outputID = fixedID("000000000003")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try fixtureImage())),
        RenderNode(id: operationID, dependencies: [sourceID], kind: .operations([.transform(scale: 0, translationX: 0, translationY: 0)])),
        RenderNode(id: outputID, dependencies: [operationID], kind: .output)
    ])

    #expect(throws: RenderError.self) {
        _ = try graph.validatedNodes()
    }
}

@Test("Cache keys are stable and parameter-sensitive SHA-256 strings")
func stableCacheKeys() throws {
    let output = try RenderOutputSpecification(width: 16, height: 16)
    let first = try RenderRequest(graph: validGraph(exposure: 0), time: .zero, output: output)
    let same = try RenderRequest(graph: validGraph(exposure: 0), time: .zero, output: output)
    let changed = try RenderRequest(graph: validGraph(exposure: 1), time: .zero, output: output)

    #expect(first.cacheKey == same.cacheKey)
    #expect(first.cacheKey != changed.cacheKey)
    #expect(first.cacheKey.rawValue.count == 64)
}

@Test("Preview and file export use the identical result bytes")
func previewExportParity() throws {
    let image = try fixtureImage(byte: 42)
    let result = RenderResult(
        image: image,
        metrics: RenderMetrics(
            cpuEncodingMilliseconds: 1,
            gpuExecutionMilliseconds: 2,
            totalMilliseconds: 3,
            inputPixelCount: 16,
            outputPixelCount: 16,
            estimatedTextureBytes: 128
        ),
        cacheKey: RenderCacheKey(rawValue: String(repeating: "a", count: 64))
    )
    let export = RenderExportPayload(result: result)
    #expect(export.data == result.image.data)
}
