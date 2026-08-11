#if canImport(Metal)
@preconcurrency import Metal
import Foundation
import VertexProcedural
import VertexRender

public struct ParticleRGBA: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct ParticleRenderStyle: Equatable, Sendable {
    public var color: ParticleRGBA
    public var additive: Bool

    public init(color: ParticleRGBA, additive: Bool) {
        self.color = color
        self.additive = additive
    }
}

public final class MetalParticleRenderer: @unchecked Sendable {
    private struct GPUInstance {
        var position: SIMD2<Float>
        var size: Float
        var opacity: Float
    }

    private struct GPUUniforms {
        var color: SIMD4<Float>
    }

    private let resources: MetalRenderResources

    public init() throws {
        resources = try MetalRenderResources()
    }

    public func render(
        states: [ParticleState],
        width: Int,
        height: Int,
        style: ParticleRenderStyle
    ) throws -> any MTLTexture {
        guard width > 0, height > 0 else {
            throw RenderError.textureAllocationFailure("Particle output dimensions must be positive.")
        }
        let texture = try resources.makeParticleTexture(width: width, height: height)
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
            throw RenderError.commandFailure("Unable to create a particle command buffer.")
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderError.commandFailure("Unable to create a particle render encoder.")
        }

        if !states.isEmpty {
            let instances = states.map {
                GPUInstance(
                    position: SIMD2(Float($0.position.x), Float($0.position.y)),
                    size: Float($0.size),
                    opacity: Float($0.opacity)
                )
            }
            guard let instanceBuffer = resources.device.makeBuffer(
                bytes: instances,
                length: MemoryLayout<GPUInstance>.stride * instances.count,
                options: .storageModeShared
            ) else {
                encoder.endEncoding()
                throw RenderError.textureAllocationFailure("Unable to allocate the particle instance buffer.")
            }
            var uniforms = GPUUniforms(color: SIMD4(style.color.red, style.color.green, style.color.blue, style.color.alpha))
            encoder.setRenderPipelineState(style.additive ? resources.particleAdditivePipeline : resources.particleNormalPipeline)
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GPUUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instances.count)
        }
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw RenderError.commandFailure("Particle render failed: \(error.localizedDescription)")
        }
        return texture
    }
}
#else
import VertexProcedural
import VertexRender

public struct ParticleRGBA: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
}

public struct ParticleRenderStyle: Equatable, Sendable {
    public var color: ParticleRGBA
    public var additive: Bool
    public init(color: ParticleRGBA, additive: Bool) { self.color = color; self.additive = additive }
}

public final class MetalParticleRenderer: @unchecked Sendable {
    public init() throws { throw RenderError.metalUnavailable }
}
#endif
