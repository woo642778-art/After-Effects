#if canImport(Metal)
@preconcurrency import Metal
import Foundation
import VertexRender

internal final class MetalRenderResources: @unchecked Sendable {
    let device: any MTLDevice
    let commandQueue: any MTLCommandQueue
    let solidPipeline: any MTLComputePipelineState
    let layerPipeline: any MTLComputePipelineState
    let compositePipeline: any MTLComputePipelineState
    let adjustmentPipeline: any MTLComputePipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.metalUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderError.commandFailure("A Metal command queue could not be created.")
        }
        let library = try Self.makeLibrary(device: device)
        solidPipeline = try Self.makePipeline(named: "vertexSolidKernel", library: library, device: device)
        layerPipeline = try Self.makePipeline(named: "vertexLayerKernel", library: library, device: device)
        compositePipeline = try Self.makePipeline(named: "vertexCompositeKernel", library: library, device: device)
        adjustmentPipeline = try Self.makePipeline(named: "vertexAdjustmentKernel", library: library, device: device)
        self.device = device
        self.commandQueue = commandQueue
    }

    func makeTexture(width: Int, height: Int) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RenderError.textureAllocationFailure("Unable to allocate a \(width) × \(height) RGBA8 texture.")
        }
        return texture
    }

    private static func makePipeline(
        named name: String,
        library: any MTLLibrary,
        device: any MTLDevice
    ) throws -> any MTLComputePipelineState {
        guard let function = library.makeFunction(name: name) else {
            throw RenderError.shaderFailure("The \(name) function is missing.")
        }
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw RenderError.shaderFailure("\(name): \(error.localizedDescription)")
        }
    }

    private static func makeLibrary(device: any MTLDevice) throws -> any MTLLibrary {
        if let compiledURL = Bundle.module.url(forResource: "default", withExtension: "metallib") {
            do {
                return try device.makeLibrary(URL: compiledURL)
            } catch {
                throw RenderError.shaderFailure("The bundled default.metallib could not be loaded: \(error.localizedDescription)")
            }
        }

        let sourceURL = Bundle.module.url(
            forResource: "VertexRenderKernels",
            withExtension: "metal",
            subdirectory: "Shaders"
        ) ?? Bundle.module.url(forResource: "VertexRenderKernels", withExtension: "metal")
        guard let sourceURL else {
            throw RenderError.shaderFailure("Neither default.metallib nor VertexRenderKernels.metal is bundled.")
        }
        do {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            return try device.makeLibrary(source: source, options: nil)
        } catch {
            throw RenderError.shaderFailure(error.localizedDescription)
        }
    }
}
#endif
