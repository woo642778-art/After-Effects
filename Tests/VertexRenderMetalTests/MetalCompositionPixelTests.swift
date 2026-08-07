#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
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

private actor NestedPixelResolver: CompositionFrameResolver {
    let image: PortableImage

    init(image: PortableImage) {
        self.image = image
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        .frame(image)
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

@Test("Nested composition compiler output renders through Metal")
func nestedCompositionRendersThroughMetal() async throws {
    let projectID = pixelID("000000000101")
    let parentID = pixelID("000000000102")
    let childID = pixelID("000000000103")
    let mediaID = pixelID("000000000104")
    let nestedLayerID = pixelID("000000000105")
    let mediaLayerID = pixelID("000000000106")
    let duration = RationalTime(value: 1, timescale: 1)
    let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: duration)

    let mediaLayer = ProjectLayer(
        id: mediaLayerID,
        compositionID: childID,
        name: "Red Source",
        source: .media(mediaID: mediaID, sourceStartTime: .zero),
        timing: timing
    )
    let nestedLayer = ProjectLayer(
        id: nestedLayerID,
        compositionID: parentID,
        name: "Nested Child",
        source: .composition(compositionID: childID, sourceStartTime: .zero),
        timing: timing
    )
    let parent = ProjectComposition(
        id: parentID,
        name: "Parent",
        width: 1,
        height: 1,
        duration: duration,
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: [nestedLayerID]
    )
    let child = ProjectComposition(
        id: childID,
        name: "Child",
        width: 1,
        height: 1,
        duration: duration,
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: [mediaLayerID]
    )
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let project = try ProjectDocument(
        projectID: projectID,
        revision: 0,
        metadata: ProjectMetadata(
            name: "Nested Pixel",
            createdAt: timestamp,
            modifiedAt: timestamp,
            createdByAppVersion: "6.0.0",
            lastSavedByAppVersion: "6.0.0"
        ),
        settings: ProjectSettings(),
        mediaRegistry: [MediaReference.fixture(id: mediaID.rawValue)],
        compositionRegistry: [parent, child],
        layerRegistry: [nestedLayer, mediaLayer],
        activeCompositionID: parentID,
        selectedLayerID: nestedLayerID,
        selectedMediaID: mediaID
    ).validated()

    let sourceImage = try MetalImageCodec.encodePNG(
        bytes: [255, 0, 0, 255],
        width: 1,
        height: 1,
        color: .rec709SDR(alphaMode: .straight)
    )
    let renderRequest = try await CompositionGraphCompiler().compile(
        CompositionRenderRequest(
            project: project,
            compositionID: parentID,
            time: .zero,
            output: RenderOutputSpecification(width: 1, height: 1)
        ),
        resolver: NestedPixelResolver(image: sourceImage),
        cancellationToken: RenderCancellationToken()
    )
    let result = try await MetalRenderBackend().render(
        renderRequest,
        cancellationToken: RenderCancellationToken()
    )
    expectPixel(try rgba(result), near: [255, 0, 0, 255])
    #expect(result.metrics.renderedLayerCount == 2)
}

@Test("Swift and Metal parameter structures retain expected 16-byte packing")
func parameterLayoutIsStable() {
    #expect(MemoryLayout<MetalSolidParameters>.stride == 16)
    #expect(MemoryLayout<MetalLayerParameters>.stride == 64)
    #expect(MemoryLayout<MetalCompositeParameters>.stride == 16)
    #expect(MemoryLayout<MetalAdjustmentParameters>.stride == 32)
}
#endif
