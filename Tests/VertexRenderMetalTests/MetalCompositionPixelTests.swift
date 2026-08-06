#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
import Foundation
import Testing
import VertexCore
import VertexRender
@testable import VertexRenderMetal

private func pixelID(_ suffix: String) -> VertexID {
    VertexID(rawValue: "66000000-0000-0000-0000-\(suffix)")
}

private func compositeRequest(
    backdrop: RenderRGBAColor,
    source: RenderRGBAColor,
    blend: RenderBlendMode
) throws -> RenderRequest {
    let backdropID = pixelID("000000000001")
    let sourceID = pixelID("000000000002")
    let compositeID = pixelID("000000000003")
    let outputID = pixelID("000000000004")
    return try RenderRequest(
        graph: RenderGraph(nodes: [
            RenderNode(id: backdropID, dependencies: [], kind: .solidColor(backdrop)),
            RenderNode(id: sourceID, dependencies: [], kind: .solidColor(source)),
            RenderNode(id: compositeID, dependencies: [backdropID, sourceID], kind: .composite(blend)),
            RenderNode(id: outputID, dependencies: [compositeID], kind: .output)
        ]),
        time: .zero,
        output: RenderOutputSpecification(width: 1, height: 1)
    )
}

private func rgba(_ result: RenderResult) throws -> [UInt8] {
    Array(try MetalImageCodec.decode(result.image).bytes.prefix(4))
}

private func expectPixel(_ actual: [UInt8], near expected: [Int], tolerance: Int = 2) {
    #expect(actual.count == expected.count)
    for index in expected.indices {
        #expect(abs(Int(actual[index]) - expected[index]) <= tolerance)
    }
}

@Test("Normal Source Over respects semitransparent premultiplied alpha")
func normalSourceOverPixel() async throws {
    let request = try compositeRequest(
        backdrop: RenderRGBAColor(red: 0, green: 0, blue: 1, alpha: 1),
        source: RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5),
        blend: .normal
    )
    let result = try await MetalRenderBackend().render(request, cancellationToken: RenderCancellationToken())
    expectPixel(try rgba(result), near: [128, 0, 128, 255])
}

@Test("Add Multiply and Screen produce deterministic opaque pixels")
func extendedBlendPixels() async throws {
    let backdrop = RenderRGBAColor(red: 0.5, green: 0.25, blue: 0, alpha: 1)
    let source = RenderRGBAColor(red: 0.25, green: 0.5, blue: 1, alpha: 1)
    let backend = try MetalRenderBackend()

    let add = try await backend.render(
        compositeRequest(backdrop: backdrop, source: source, blend: .add),
        cancellationToken: RenderCancellationToken()
    )
    expectPixel(try rgba(add), near: [191, 191, 255, 255])

    let multiply = try await backend.render(
        compositeRequest(backdrop: backdrop, source: source, blend: .multiply),
        cancellationToken: RenderCancellationToken()
    )
    expectPixel(try rgba(multiply), near: [32, 32, 0, 255])

    let screen = try await backend.render(
        compositeRequest(backdrop: backdrop, source: source, blend: .screen),
        cancellationToken: RenderCancellationToken()
    )
    expectPixel(try rgba(screen), near: [159, 159, 255, 255])
}

@Test("Fully transparent source RGB cannot contaminate the backdrop")
func transparentRGBDoesNotLeak() async throws {
    let result = try await MetalRenderBackend().render(
        compositeRequest(
            backdrop: RenderRGBAColor(red: 0, green: 0, blue: 1, alpha: 1),
            source: RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 0),
            blend: .normal
        ),
        cancellationToken: RenderCancellationToken()
    )
    expectPixel(try rgba(result), near: [0, 0, 255, 255])
}

@Test("Adjustment exposure mixes over the accumulated result")
func adjustmentExposurePixel() async throws {
    let sourceID = pixelID("000000000011")
    let adjustmentID = pixelID("000000000012")
    let outputID = pixelID("000000000013")
    let request = try RenderRequest(
        graph: RenderGraph(nodes: [
            RenderNode(
                id: sourceID,
                dependencies: [],
                kind: .solidColor(RenderRGBAColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1))
            ),
            RenderNode(
                id: adjustmentID,
                dependencies: [sourceID],
                kind: .adjustment([.exposure(stops: 1)], mix: 1)
            ),
            RenderNode(id: outputID, dependencies: [adjustmentID], kind: .output)
        ]),
        time: .zero,
        output: RenderOutputSpecification(width: 1, height: 1)
    )
    let result = try await MetalRenderBackend().render(request, cancellationToken: RenderCancellationToken())
    expectPixel(try rgba(result), near: [128, 128, 128, 255])
    #expect(result.metrics.expandedNodeCount == 3)
    #expect(result.metrics.renderedLayerCount == 1)
}

@Test("Swift and Metal parameter structures retain expected 16-byte packing")
func parameterLayoutIsStable() {
    #expect(MemoryLayout<MetalSolidParameters>.stride == 16)
    #expect(MemoryLayout<MetalLayerParameters>.stride == 64)
    #expect(MemoryLayout<MetalCompositeParameters>.stride == 16)
    #expect(MemoryLayout<MetalAdjustmentParameters>.stride == 32)
}
#endif
