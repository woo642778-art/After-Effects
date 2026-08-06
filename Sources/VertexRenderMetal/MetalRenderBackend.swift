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
        _ = try request.graph.validatedNodes()

        let totalStart = ProcessInfo.processInfo.systemUptime
        let preGPUStart = ProcessInfo.processInfo.systemUptime
        let sourceImage = try request.graph.sourceImage()
        let decoded = try MetalImageCodec.decode(sourceImage)
        let operations = try request.graph.flattenedOperations()
        let parameters = try Self.parameters(
            inputWidth: decoded.width,
            inputHeight: decoded.height,
            outputWidth: request.output.width,
            outputHeight: request.output.height,
            operations: operations
        )

        let inputTexture = try resources.makeTexture(
            width: decoded.width,
            height: decoded.height,
            usage: [.shaderRead]
        )
        decoded.bytes.withUnsafeBytes { buffer in
            inputTexture.replace(
                region: MTLRegionMake2D(0, 0, decoded.width, decoded.height),
                mipmapLevel: 0,
                withBytes: buffer.baseAddress!,
                bytesPerRow: decoded.width * 4
            )
        }

        let outputTexture = try resources.makeTexture(
            width: request.output.width,
            height: request.output.height,
            usage: [.shaderWrite]
        )
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("A Metal command buffer or compute encoder could not be created.")
        }

        encoder.label = "Vertex Phase 4 Render"
        encoder.setComputePipelineState(resources.pipeline)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        var mutableParameters = parameters
        encoder.setBytes(
            &mutableParameters,
            length: MemoryLayout<MetalRenderParameters>.stride,
            index: 0
        )

        let threadWidth = resources.pipeline.threadExecutionWidth
        let threadHeight = max(1, resources.pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(
            MTLSize(width: request.output.width, height: request.output.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
        encoder.endEncoding()
        let preGPUEnd = ProcessInfo.processInfo.systemUptime

        try await cancellationToken.throwIfCancelled()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if commandBuffer.status == .error {
            throw RenderError.commandFailure(commandBuffer.error?.localizedDescription ?? "The GPU command buffer failed.")
        }
        try await cancellationToken.throwIfCancelled()

        let postGPUStart = ProcessInfo.processInfo.systemUptime
        var outputBytes = Array(
            repeating: UInt8(0),
            count: request.output.width * request.output.height * 4
        )
        outputBytes.withUnsafeMutableBytes { buffer in
            outputTexture.getBytes(
                buffer.baseAddress!,
                bytesPerRow: request.output.width * 4,
                from: MTLRegionMake2D(0, 0, request.output.width, request.output.height),
                mipmapLevel: 0
            )
        }
        let portableImage = try MetalImageCodec.encodePNG(
            bytes: outputBytes,
            width: request.output.width,
            height: request.output.height,
            color: request.output.color
        )
        let postGPUEnd = ProcessInfo.processInfo.systemUptime

        let gpuMilliseconds: Double?
        if commandBuffer.gpuEndTime > commandBuffer.gpuStartTime {
            gpuMilliseconds = (commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1_000
        } else {
            gpuMilliseconds = nil
        }

        let cpuMilliseconds = ((preGPUEnd - preGPUStart) + (postGPUEnd - postGPUStart)) * 1_000
        let totalMilliseconds = (postGPUEnd - totalStart) * 1_000
        let metrics = RenderMetrics(
            cpuEncodingMilliseconds: cpuMilliseconds,
            gpuExecutionMilliseconds: gpuMilliseconds,
            totalMilliseconds: totalMilliseconds,
            inputPixelCount: decoded.width * decoded.height,
            outputPixelCount: request.output.width * request.output.height,
            estimatedTextureBytes: (decoded.width * decoded.height + request.output.width * request.output.height) * 4
        )
        return RenderResult(image: portableImage, metrics: metrics, cacheKey: request.cacheKey)
    }

    private static func parameters(
        inputWidth: Int,
        inputHeight: Int,
        outputWidth: Int,
        outputHeight: Int,
        operations: [RenderOperation]
    ) throws -> MetalRenderParameters {
        var scale: Float = 1
        var translationX: Float = 0
        var translationY: Float = 0
        var exposure: Float = 0
        var saturation: Float = 1
        var opacity: Float = 1
        var invert: UInt32 = 0

        for operation in operations {
            _ = try operation.validated()
            switch operation {
            case .transform(let value, let x, let y):
                scale = Float(value)
                translationX = Float(x)
                translationY = Float(y)
            case .exposure(let stops):
                exposure = Float(stops)
            case .saturation(let value):
                saturation = Float(max(0, min(4, value)))
            case .invert(let enabled):
                invert = enabled ? 1 : 0
            case .opacity(let value):
                opacity = Float(max(0, min(1, value)))
            }
        }

        return MetalRenderParameters(
            dimensions: SIMD4(
                UInt32(inputWidth),
                UInt32(inputHeight),
                UInt32(outputWidth),
                UInt32(outputHeight)
            ),
            scale: scale,
            translationX: translationX,
            translationY: translationY,
            exposure: exposure,
            saturation: saturation,
            opacity: opacity,
            invert: invert
        )
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
