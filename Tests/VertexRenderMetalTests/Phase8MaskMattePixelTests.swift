#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
import Foundation
import Testing
import VertexCore
import VertexRender
@testable import VertexRenderMetal

private func phase8MetalID(_ suffix: String) -> VertexID {
    VertexID(rawValue: "85000000-0000-0000-0000-\(suffix)")
}

private func decodedBytes(_ result: RenderResult) throws -> [UInt8] {
    Array(try MetalImageCodec.decode(result.image).bytes)
}

private func pixel(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> ArraySlice<UInt8> {
    let offset = (y * width + x) * 4
    return bytes[offset..<(offset + 4)]
}

private func rectangleMask(
    min: Double,
    max: Double,
    mode: RenderMaskMode = .add,
    inverted: Bool = false,
    opacity: Double = 1,
    feather: Double = 0,
    expansion: Double = 0
) -> RenderMaskDefinition {
    RenderMaskDefinition(
        segments: [
            .init(start: .init(x: min, y: min), end: .init(x: max, y: min)),
            .init(start: .init(x: max, y: min), end: .init(x: max, y: max)),
            .init(start: .init(x: max, y: max), end: .init(x: min, y: max)),
            .init(start: .init(x: min, y: max), end: .init(x: min, y: min))
        ],
        mode: mode,
        opacity: opacity,
        featherPixels: feather,
        expansionPixels: expansion,
        inverted: inverted,
        enabled: true
    )
}

@Test("Metal mask node clips source pixels and invert reverses coverage")
func metalMaskClipsAndInverts() async throws {
    let sourceID = phase8MetalID("000000000001")
    let maskID = phase8MetalID("000000000002")
    let outputID = phase8MetalID("000000000003")
    let stack = RenderMaskStack(masks: [rectangleMask(min: 0.2, max: 0.8)])
    let request = try RenderRequest(
        graph: RenderGraph(nodes: [
            RenderNode(
                id: sourceID,
                dependencies: [],
                kind: .solidColor(RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 1))
            ),
            RenderNode(id: maskID, dependencies: [sourceID], kind: .mask(stack)),
            RenderNode(id: outputID, dependencies: [maskID], kind: .output)
        ]),
        time: .zero,
        output: RenderOutputSpecification(width: 5, height: 5)
    )
    let backend = try MetalRenderBackend()
    let result = try await backend.render(request, cancellationToken: RenderCancellationToken())
    let bytes = try decodedBytes(result)
    #expect(pixel(bytes, width: 5, x: 2, y: 2)[pixel(bytes, width: 5, x: 2, y: 2).startIndex + 3] >= 250)
    #expect(pixel(bytes, width: 5, x: 0, y: 0)[pixel(bytes, width: 5, x: 0, y: 0).startIndex + 3] <= 2)

    let invertedMaskID = phase8MetalID("000000000004")
    let invertedOutputID = phase8MetalID("000000000005")
    let invertedRequest = try RenderRequest(
        graph: RenderGraph(nodes: [
            RenderNode(
                id: sourceID,
                dependencies: [],
                kind: .solidColor(RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 1))
            ),
            RenderNode(
                id: invertedMaskID,
                dependencies: [sourceID],
                kind: .mask(RenderMaskStack(masks: [rectangleMask(min: 0.2, max: 0.8, inverted: true)]))
            ),
            RenderNode(id: invertedOutputID, dependencies: [invertedMaskID], kind: .output)
        ]),
        time: .zero,
        output: RenderOutputSpecification(width: 5, height: 5)
    )
    let inverted = try await backend.render(invertedRequest, cancellationToken: RenderCancellationToken())
    let invertedBytes = try decodedBytes(inverted)
    #expect(pixel(invertedBytes, width: 5, x: 2, y: 2)[pixel(invertedBytes, width: 5, x: 2, y: 2).startIndex + 3] <= 2)
    #expect(pixel(invertedBytes, width: 5, x: 0, y: 0)[pixel(invertedBytes, width: 5, x: 0, y: 0).startIndex + 3] >= 250)
}

@Test("Metal mask stack applies subtract and intersect in saved order")
func metalMaskOrderedCombination() async throws {
    let sourceID = phase8MetalID("000000000011")
    let maskID = phase8MetalID("000000000012")
    let outputID = phase8MetalID("000000000013")
    let stack = RenderMaskStack(masks: [
        rectangleMask(min: 0.0, max: 1.0, mode: .add),
        rectangleMask(min: 0.3, max: 0.7, mode: .subtract)
    ])
    let request = try RenderRequest(
        graph: RenderGraph(nodes: [
            RenderNode(id: sourceID, dependencies: [], kind: .solidColor(RenderRGBAColor(red: 0, green: 1, blue: 0, alpha: 1))),
            RenderNode(id: maskID, dependencies: [sourceID], kind: .mask(stack)),
            RenderNode(id: outputID, dependencies: [maskID], kind: .output)
        ]),
        time: .zero,
        output: RenderOutputSpecification(width: 5, height: 5)
    )
    let result = try await MetalRenderBackend().render(request, cancellationToken: RenderCancellationToken())
    let bytes = try decodedBytes(result)
    let center = Array(pixel(bytes, width: 5, x: 2, y: 2))
    let edge = Array(pixel(bytes, width: 5, x: 0, y: 0))
    #expect(center[3] <= 2)
    #expect(edge[3] >= 250)
}

@Test("Metal track matte supports alpha luma and inverted coverage")
func metalTrackMatteCoverageModes() async throws {
    let backend = try MetalRenderBackend()

    func request(mode: RenderTrackMatteMode, matte: RenderRGBAColor) throws -> RenderRequest {
        let sourceID = VertexID()
        let matteID = VertexID()
        let applyID = VertexID()
        let outputID = VertexID()
        return try RenderRequest(
            graph: RenderGraph(nodes: [
                RenderNode(id: sourceID, dependencies: [], kind: .solidColor(RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 1))),
                RenderNode(id: matteID, dependencies: [], kind: .solidColor(matte)),
                RenderNode(id: applyID, dependencies: [sourceID, matteID], kind: .matte(mode)),
                RenderNode(id: outputID, dependencies: [applyID], kind: .output)
            ]),
            time: .zero,
            output: RenderOutputSpecification(width: 1, height: 1)
        )
    }

    let alpha = try await backend.render(
        request(mode: .alpha, matte: RenderRGBAColor(red: 1, green: 1, blue: 1, alpha: 0.5)),
        cancellationToken: RenderCancellationToken()
    )
    let alphaPixel = Array(try decodedBytes(alpha).prefix(4))
    #expect(abs(Int(alphaPixel[3]) - 128) <= 3)
    #expect(abs(Int(alphaPixel[0]) - 128) <= 3)

    let alphaInverted = try await backend.render(
        request(mode: .alphaInverted, matte: RenderRGBAColor(red: 1, green: 1, blue: 1, alpha: 0.25)),
        cancellationToken: RenderCancellationToken()
    )
    let invertedPixel = Array(try decodedBytes(alphaInverted).prefix(4))
    #expect(abs(Int(invertedPixel[3]) - 191) <= 3)

    let luma = try await backend.render(
        request(mode: .luma, matte: RenderRGBAColor(red: 1, green: 0, blue: 0, alpha: 1)),
        cancellationToken: RenderCancellationToken()
    )
    let lumaPixel = Array(try decodedBytes(luma).prefix(4))
    #expect(abs(Int(lumaPixel[3]) - 54) <= 4)
}

@Test("Phase 8 Metal parameter structures retain 16-byte compatible packing")
func phase8MetalParameterLayout() {
    #expect(MemoryLayout<MetalMaskParameters>.stride == 16)
    #expect(MemoryLayout<MetalMaskHeader>.stride == 32)
    #expect(MemoryLayout<MetalMaskSegment>.stride == 16)
    #expect(MemoryLayout<MetalMatteParameters>.stride == 16)
}
#endif
