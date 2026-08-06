#if canImport(Metal)
@preconcurrency import Metal
import Foundation
import VertexRender

internal struct MetalRenderParameters {
    var dimensions: SIMD4<UInt32>
    var scale: Float
    var translationX: Float
    var translationY: Float
    var exposure: Float
    var saturation: Float
    var opacity: Float
    var invert: UInt32
    var padding: UInt32 = 0
}

internal final class MetalRenderResources: @unchecked Sendable {
    let device: any MTLDevice
    let commandQueue: any MTLCommandQueue
    let pipeline: any MTLComputePipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.metalUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderError.commandFailure("A Metal command queue could not be created.")
        }

        let sourceURL = Bundle.module.url(
            forResource: "VertexRenderKernels",
            withExtension: "metal",
            subdirectory: "Shaders"
        ) ?? Bundle.module.url(forResource: "VertexRenderKernels", withExtension: "metal")
        guard let sourceURL else {
            throw RenderError.shaderFailure("The bundled VertexRenderKernels.metal source is missing.")
        }

        let source: String
        do {
            source = try String(contentsOf: sourceURL, encoding: .utf8)
        } catch {
            throw RenderError.shaderFailure("The bundled shader source could not be read: \(error.localizedDescription)")
        }

        let library: any MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: nil)
        } catch {
            throw RenderError.shaderFailure(error.localizedDescription)
        }
        guard let function = library.makeFunction(name: "vertexRenderKernel") else {
            throw RenderError.shaderFailure("The vertexRenderKernel function is missing.")
        }

        do {
            pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw RenderError.shaderFailure(error.localizedDescription)
        }
        self.device = device
        self.commandQueue = commandQueue
    }

    func makeTexture(width: Int, height: Int, usage: MTLTextureUsage) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RenderError.textureAllocationFailure("Unable to allocate a \(width) × \(height) RGBA8 texture.")
        }
        return texture
    }
}
#endif
