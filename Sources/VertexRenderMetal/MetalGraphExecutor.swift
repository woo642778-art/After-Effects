#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
@preconcurrency import Metal
import Foundation
import VertexCore
import VertexRender

internal struct MetalGraphExecutionResult: @unchecked Sendable {
    let texture: any MTLTexture
    let decodedInputPixelCount: Int
    let renderedLayerCount: Int
    let expandedNodeCount: Int
    let estimatedPeakTextureBytes: Int
    let gpuMilliseconds: Double?
}

private struct MetalTextureValue {
    let texture: any MTLTexture
    let width: Int
    let height: Int
}

internal struct MetalGraphExecutor {
    func execute(
        plan: RenderEvaluationPlan,
        output: RenderOutputSpecification,
        resources: MetalRenderResources,
        cancellationToken: RenderCancellationToken
    ) async throws -> MetalGraphExecutionResult {
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
            throw RenderError.commandFailure("A Metal command buffer could not be created.")
        }
        commandBuffer.label = "Vertex Phase 8 Composition Graph"

        let pool = MetalTexturePool(resources: resources)
        var values: [VertexID: MetalTextureValue] = [:]
        var remainingConsumers = plan.consumerCounts
        var decodedPixels = 0
        var renderedLayers = 0

        for node in plan.orderedNodes {
            try await cancellationToken.throwIfCancelled()
            switch node.kind {
            case .source(let image):
                let decoded = try MetalImageCodec.decode(image)
                decodedPixels += decoded.width * decoded.height
                let texture = try pool.acquire(width: decoded.width, height: decoded.height)
                decoded.bytes.withUnsafeBytes { buffer in
                    texture.replace(
                        region: MTLRegionMake2D(0, 0, decoded.width, decoded.height),
                        mipmapLevel: 0,
                        withBytes: buffer.baseAddress!,
                        bytesPerRow: decoded.width * 4
                    )
                }
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: decoded.width,
                    height: decoded.height
                )

            case .solidColor(let color):
                let texture = try pool.acquire(width: output.width, height: output.height)
                try encodeSolid(
                    color: color,
                    output: texture,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: output.width,
                    height: output.height
                )

            case .operations(let operations):
                let input = try dependencyValue(node.dependencies[0], values: values)
                let texture = try pool.acquire(width: output.width, height: output.height)
                try encodeLayer(
                    input: input,
                    output: texture,
                    outputWidth: output.width,
                    outputHeight: output.height,
                    operations: operations,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: output.width,
                    height: output.height
                )
                releaseConsumedDependencies(
                    node.dependencies,
                    values: &values,
                    remainingConsumers: &remainingConsumers,
                    pool: pool
                )

            case .mask(let stack):
                let input = try dependencyValue(node.dependencies[0], values: values)
                let texture = try pool.acquire(width: input.width, height: input.height)
                try encodeMask(
                    input: input.texture,
                    output: texture,
                    width: input.width,
                    height: input.height,
                    stack: stack,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: input.width,
                    height: input.height
                )
                releaseConsumedDependencies(
                    node.dependencies,
                    values: &values,
                    remainingConsumers: &remainingConsumers,
                    pool: pool
                )

            case .matte(let mode):
                let source = try dependencyValue(node.dependencies[0], values: values)
                let matte = try dependencyValue(node.dependencies[1], values: values)
                let texture = try pool.acquire(width: source.width, height: source.height)
                try encodeMatte(
                    source: source.texture,
                    matte: matte.texture,
                    output: texture,
                    width: source.width,
                    height: source.height,
                    mode: mode,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: source.width,
                    height: source.height
                )
                releaseConsumedDependencies(
                    node.dependencies,
                    values: &values,
                    remainingConsumers: &remainingConsumers,
                    pool: pool
                )

            case .composite(let blendMode):
                let backdrop = try dependencyValue(node.dependencies[0], values: values)
                let source = try dependencyValue(node.dependencies[1], values: values)
                let texture = try pool.acquire(width: output.width, height: output.height)
                try encodeComposite(
                    backdrop: backdrop.texture,
                    source: source.texture,
                    output: texture,
                    width: output.width,
                    height: output.height,
                    blendMode: blendMode,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: output.width,
                    height: output.height
                )
                renderedLayers += 1
                releaseConsumedDependencies(
                    node.dependencies,
                    values: &values,
                    remainingConsumers: &remainingConsumers,
                    pool: pool
                )

            case .adjustment(let operations, let mix):
                let input = try dependencyValue(node.dependencies[0], values: values)
                let texture = try pool.acquire(width: output.width, height: output.height)
                try encodeAdjustment(
                    input: input.texture,
                    output: texture,
                    width: output.width,
                    height: output.height,
                    operations: operations,
                    mix: mix,
                    resources: resources,
                    commandBuffer: commandBuffer
                )
                values[node.id] = MetalTextureValue(
                    texture: texture,
                    width: output.width,
                    height: output.height
                )
                renderedLayers += 1
                releaseConsumedDependencies(
                    node.dependencies,
                    values: &values,
                    remainingConsumers: &remainingConsumers,
                    pool: pool
                )

            case .output:
                let input = try dependencyValue(node.dependencies[0], values: values)
                if input.width == output.width, input.height == output.height {
                    values[node.id] = input
                } else {
                    let texture = try pool.acquire(width: output.width, height: output.height)
                    try encodeLayer(
                        input: input,
                        output: texture,
                        outputWidth: output.width,
                        outputHeight: output.height,
                        operations: [.transform2D(.identity), .opacity(1)],
                        resources: resources,
                        commandBuffer: commandBuffer
                    )
                    values[node.id] = MetalTextureValue(
                        texture: texture,
                        width: output.width,
                        height: output.height
                    )
                }
            }
        }

        try await cancellationToken.throwIfCancelled()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status != .error else {
            throw RenderError.commandFailure(
                commandBuffer.error?.localizedDescription
                    ?? "The composition command buffer failed."
            )
        }
        try await cancellationToken.throwIfCancelled()
        guard let final = values[plan.outputNodeID] else {
            throw RenderError.commandFailure("The render graph did not produce an output texture.")
        }

        let gpuMilliseconds: Double?
        if commandBuffer.gpuEndTime > commandBuffer.gpuStartTime {
            gpuMilliseconds = (commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1_000
        } else {
            gpuMilliseconds = nil
        }
        return MetalGraphExecutionResult(
            texture: final.texture,
            decodedInputPixelCount: decodedPixels,
            renderedLayerCount: renderedLayers,
            expandedNodeCount: plan.orderedNodes.count,
            estimatedPeakTextureBytes: pool.estimatedPeakBytes,
            gpuMilliseconds: gpuMilliseconds
        )
    }

    private func dependencyValue(
        _ id: VertexID,
        values: [VertexID: MetalTextureValue]
    ) throws -> MetalTextureValue {
        guard let value = values[id] else {
            throw RenderError.commandFailure(
                "A dependency texture is unavailable: \(id.rawValue)."
            )
        }
        return value
    }

    private func releaseConsumedDependencies(
        _ dependencies: [VertexID],
        values: inout [VertexID: MetalTextureValue],
        remainingConsumers: inout [VertexID: Int],
        pool: MetalTexturePool
    ) {
        for dependency in dependencies {
            let remaining = max(0, (remainingConsumers[dependency] ?? 1) - 1)
            remainingConsumers[dependency] = remaining
            if remaining == 0, let value = values.removeValue(forKey: dependency) {
                pool.release(value.texture)
            }
        }
    }

    private func encodeSolid(
        color: RenderRGBAColor,
        output: any MTLTexture,
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure(
                "A solid-color compute encoder could not be created."
            )
        }
        encoder.label = "Vertex Solid"
        encoder.setComputePipelineState(resources.solidPipeline)
        encoder.setTexture(output, index: 0)
        var parameters = MetalSolidParameters(
            color: SIMD4(
                Float(color.red),
                Float(color.green),
                Float(color.blue),
                Float(color.alpha)
            )
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalSolidParameters>.stride,
            index: 0
        )
        dispatch(
            encoder: encoder,
            pipeline: resources.solidPipeline,
            width: output.width,
            height: output.height
        )
        encoder.endEncoding()
    }

    private func encodeLayer(
        input: MetalTextureValue,
        output: any MTLTexture,
        outputWidth: Int,
        outputHeight: Int,
        operations: [RenderOperation],
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        var transform = RenderTransform2D.identity
        var exposure: Float = 0
        var saturation: Float = 1
        var opacity: Float = 1
        var invert: Float = 0
        for operation in operations {
            _ = try operation.validated()
            switch operation {
            case .transform(let scale, let x, let y):
                transform = RenderTransform2D(
                    positionX: 0.5 + x,
                    positionY: 0.5 + y,
                    anchorX: 0.5,
                    anchorY: 0.5,
                    scaleX: scale,
                    scaleY: scale,
                    rotationDegrees: 0
                )
            case .transform2D(let value):
                transform = value
            case .exposure(let stops):
                exposure = Float(stops)
            case .saturation(let value):
                saturation = Float(value)
            case .invert(let enabled):
                invert = enabled ? 1 : 0
            case .opacity(let value):
                opacity = Float(value)
            }
        }

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("A layer compute encoder could not be created.")
        }
        encoder.label = "Vertex Layer"
        encoder.setComputePipelineState(resources.layerPipeline)
        encoder.setTexture(input.texture, index: 0)
        encoder.setTexture(output, index: 1)
        var parameters = MetalLayerParameters(
            dimensions: SIMD4(
                UInt32(input.width),
                UInt32(input.height),
                UInt32(outputWidth),
                UInt32(outputHeight)
            ),
            positionAnchor: SIMD4(
                Float(transform.positionX),
                Float(transform.positionY),
                Float(transform.anchorX),
                Float(transform.anchorY)
            ),
            scaleRotationOpacity: SIMD4(
                Float(transform.scaleX),
                Float(transform.scaleY),
                Float(transform.rotationDegrees * .pi / 180),
                opacity
            ),
            effects: SIMD4(exposure, saturation, invert, 0)
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalLayerParameters>.stride,
            index: 0
        )
        dispatch(
            encoder: encoder,
            pipeline: resources.layerPipeline,
            width: outputWidth,
            height: outputHeight
        )
        encoder.endEncoding()
    }

    private func encodeMask(
        input: any MTLTexture,
        output: any MTLTexture,
        width: Int,
        height: Int,
        stack: RenderMaskStack,
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        let validated = try stack.validated()
        var headers: [MetalMaskHeader] = []
        var segments: [MetalMaskSegment] = []
        headers.reserveCapacity(validated.masks.count)
        segments.reserveCapacity(validated.masks.reduce(0) { $0 + $1.segments.count })

        for mask in validated.masks {
            let offset = segments.count
            for segment in mask.segments {
                segments.append(MetalMaskSegment(
                    endpoints: SIMD4(
                        Float(segment.start.x),
                        Float(segment.start.y),
                        Float(segment.end.x),
                        Float(segment.end.y)
                    )
                ))
            }
            var flags: UInt32 = 0
            if mask.enabled { flags |= 1 }
            if mask.inverted { flags |= 2 }
            headers.append(MetalMaskHeader(
                metadata: SIMD4(
                    UInt32(offset),
                    UInt32(mask.segments.count),
                    mask.mode.metalValue,
                    flags
                ),
                effects: SIMD4(
                    Float(mask.opacity),
                    Float(mask.featherPixels),
                    Float(mask.expansionPixels),
                    0
                )
            ))
        }

        let headerBuffer = try makeBuffer(headers, resources: resources, label: "Vertex Mask Headers")
        let segmentBuffer = try makeBuffer(segments, resources: resources, label: "Vertex Mask Segments")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("A mask compute encoder could not be created.")
        }
        encoder.label = "Vertex Masks"
        encoder.setComputePipelineState(resources.maskPipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        var parameters = MetalMaskParameters(
            dimensionsAndCounts: SIMD4(
                UInt32(width),
                UInt32(height),
                UInt32(headers.count),
                UInt32(segments.count)
            )
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalMaskParameters>.stride,
            index: 0
        )
        encoder.setBuffer(headerBuffer, offset: 0, index: 1)
        encoder.setBuffer(segmentBuffer, offset: 0, index: 2)
        dispatch(
            encoder: encoder,
            pipeline: resources.maskPipeline,
            width: width,
            height: height
        )
        encoder.endEncoding()
    }

    private func encodeMatte(
        source: any MTLTexture,
        matte: any MTLTexture,
        output: any MTLTexture,
        width: Int,
        height: Int,
        mode: RenderTrackMatteMode,
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("A track-matte compute encoder could not be created.")
        }
        encoder.label = "Vertex Track Matte"
        encoder.setComputePipelineState(resources.mattePipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(matte, index: 1)
        encoder.setTexture(output, index: 2)
        var parameters = MetalMatteParameters(
            dimensionsAndMode: SIMD4(
                UInt32(width),
                UInt32(height),
                mode.metalValue,
                0
            )
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalMatteParameters>.stride,
            index: 0
        )
        dispatch(
            encoder: encoder,
            pipeline: resources.mattePipeline,
            width: width,
            height: height
        )
        encoder.endEncoding()
    }

    private func makeBuffer<T>(
        _ values: [T],
        resources: MetalRenderResources,
        label: String
    ) throws -> any MTLBuffer {
        guard !values.isEmpty else {
            throw RenderError.invalidRequest("\(label) cannot be empty.")
        }
        let length = values.count * MemoryLayout<T>.stride
        let buffer: (any MTLBuffer)? = values.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return nil }
            return resources.device.makeBuffer(bytes: baseAddress, length: length)
        }
        guard let buffer else {
            throw RenderError.commandFailure("\(label) could not be allocated.")
        }
        buffer.label = label
        return buffer
    }

    private func encodeComposite(
        backdrop: any MTLTexture,
        source: any MTLTexture,
        output: any MTLTexture,
        width: Int,
        height: Int,
        blendMode: RenderBlendMode,
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("A composite compute encoder could not be created.")
        }
        encoder.label = "Vertex Composite \(blendMode.rawValue)"
        encoder.setComputePipelineState(resources.compositePipeline)
        encoder.setTexture(backdrop, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setTexture(output, index: 2)
        var parameters = MetalCompositeParameters(
            dimensionsAndMode: SIMD4(
                UInt32(width),
                UInt32(height),
                blendMode.metalValue,
                0
            )
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalCompositeParameters>.stride,
            index: 0
        )
        dispatch(
            encoder: encoder,
            pipeline: resources.compositePipeline,
            width: width,
            height: height
        )
        encoder.endEncoding()
    }

    private func encodeAdjustment(
        input: any MTLTexture,
        output: any MTLTexture,
        width: Int,
        height: Int,
        operations: [RenderOperation],
        mix: Double,
        resources: MetalRenderResources,
        commandBuffer: any MTLCommandBuffer
    ) throws {
        var exposure: Float = 0
        var saturation: Float = 1
        var invert: Float = 0
        for operation in operations {
            _ = try operation.validated()
            switch operation {
            case .exposure(let stops):
                exposure = Float(stops)
            case .saturation(let value):
                saturation = Float(value)
            case .invert(let enabled):
                invert = enabled ? 1 : 0
            case .opacity, .transform, .transform2D:
                throw RenderError.invalidRequest(
                    "Adjustment nodes support exposure, saturation, and inversion only."
                )
            }
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RenderError.commandFailure("An adjustment compute encoder could not be created.")
        }
        encoder.label = "Vertex Adjustment"
        encoder.setComputePipelineState(resources.adjustmentPipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        var parameters = MetalAdjustmentParameters(
            dimensions: SIMD4(UInt32(width), UInt32(height), 0, 0),
            effectsAndMix: SIMD4(exposure, saturation, invert, Float(mix))
        )
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<MetalAdjustmentParameters>.stride,
            index: 0
        )
        dispatch(
            encoder: encoder,
            pipeline: resources.adjustmentPipeline,
            width: width,
            height: height
        )
        encoder.endEncoding()
    }

    private func dispatch(
        encoder: any MTLComputeCommandEncoder,
        pipeline: any MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(
                width: threadWidth,
                height: threadHeight,
                depth: 1
            )
        )
    }
}
#endif
