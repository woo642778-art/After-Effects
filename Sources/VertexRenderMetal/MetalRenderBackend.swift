#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
@preconcurrency import Metal
import Foundation
import VertexMedia
import VertexRender

public actor MetalRenderBackend: RenderBackend {
    private let resources: MetalRenderResources

    public init() throws {
        self.resources = try MetalRenderResources()
    }

    public func render(
        _ request: RenderRequest,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderResult {
        try await cancellationToken.throwIfCancelled()
        let totalStart = ProcessInfo.processInfo.systemUptime
        let cpuStart = ProcessInfo.processInfo.systemUptime
        let plan = try request.graph.evaluationPlan()
        let execution = try await MetalGraphExecutor().execute(
            plan: plan,
            output: request.output,
            resources: resources,
            cancellationToken: cancellationToken
        )

        var outputBytes = Array(
            repeating: UInt8(0),
            count: request.output.width * request.output.height * 4
        )
        outputBytes.withUnsafeMutableBytes { buffer in
            execution.texture.getBytes(
                buffer.baseAddress!,
                bytesPerRow: request.output.width * 4,
                from: MTLRegionMake2D(0, 0, request.output.width, request.output.height),
                mipmapLevel: 0
            )
        }
        let image = try MetalImageCodec.encodePNG(
            bytes: outputBytes,
            width: request.output.width,
            height: request.output.height,
            color: request.output.color
        )
        try await cancellationToken.throwIfCancelled()

        let end = ProcessInfo.processInfo.systemUptime
        let metrics = RenderMetrics(
            cpuEncodingMilliseconds: (end - cpuStart) * 1_000,
            gpuExecutionMilliseconds: execution.gpuMilliseconds,
            totalMilliseconds: (end - totalStart) * 1_000,
            inputPixelCount: execution.decodedInputPixelCount,
            outputPixelCount: request.output.width * request.output.height,
            expandedNodeCount: execution.expandedNodeCount,
            renderedLayerCount: execution.renderedLayerCount,
            estimatedPeakTextureBytes: execution.estimatedPeakTextureBytes
        )
        return RenderResult(image: image, metrics: metrics, cacheKey: request.cacheKey)
    }
}
#else
import VertexRender

public actor MetalRenderBackend: RenderBackend {
    public init() throws {
        throw RenderError.metalUnavailable
    }

    public func render(
        _ request: RenderRequest,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderResult {
        throw RenderError.metalUnavailable
    }
}
#endif
