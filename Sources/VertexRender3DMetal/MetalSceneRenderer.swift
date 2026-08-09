import Foundation
import Vertex3D

#if canImport(MetalKit) && canImport(simd)
@preconcurrency import MetalKit
import simd

public enum MetalSceneRendererError: Error {
    case metalUnavailable
    case commandQueueUnavailable
    case shaderCompilationFailed
    case pipelineCreationFailed
}

@MainActor
public final class MetalSceneRenderer: NSObject, MTKViewDelegate {
    private struct GPUVertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    private struct Uniforms {
        var modelViewProjection: simd_float4x4
        var model: simd_float4x4
    }

    public var scene: Scene3DDocument {
        didSet { invalidateView() }
    }

    private weak var view: MTKView?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    public init(view: MTKView, scene: Scene3DDocument = .starter) throws {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else { throw MetalSceneRendererError.metalUnavailable }
        guard let queue = device.makeCommandQueue() else { throw MetalSceneRendererError.commandQueueUnavailable }
        self.device = device
        self.commandQueue = queue
        self.scene = scene
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.035, green: 0.037, blue: 0.045, alpha: 1)
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.preferredFramesPerSecond = 60

        guard let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            throw MetalSceneRendererError.shaderCompilationFailed
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw MetalSceneRendererError.pipelineCreationFailed
        }
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .less
        depth.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depth) else { throw MetalSceneRendererError.pipelineCreationFailed }
        self.depthState = depthState
        self.view = view
        super.init()
        view.delegate = self
    }

    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)

        let camera = activeCamera()
        let aspect = max(Float(view.drawableSize.width / max(view.drawableSize.height, 1)), 0.001)
        let viewMatrix = Self.translation(SIMD3<Float>(-Float(camera.position.x), -Float(camera.position.y), -Float(camera.position.z)))
        let projection = Self.perspective(
            fovYRadians: Float(camera.camera.fieldOfViewDegrees * .pi / 180),
            aspect: aspect,
            near: Float(camera.camera.nearClip),
            far: Float(camera.camera.farClip)
        )

        for node in scene.nodes where node.isVisible {
            guard case .mesh(let mesh, _) = node.payload, !mesh.vertices.isEmpty, !mesh.triangles.isEmpty else { continue }
            let gpuVertices = mesh.vertices.map {
                GPUVertex(
                    position: SIMD3<Float>(Float($0.position.x), Float($0.position.y), Float($0.position.z)),
                    normal: SIMD3<Float>(Float($0.normal.x), Float($0.normal.y), Float($0.normal.z))
                )
            }
            let indices = mesh.triangles.flatMap { [UInt32($0.a), UInt32($0.b), UInt32($0.c)] }
            guard let vertexBuffer = device.makeBuffer(bytes: gpuVertices, length: MemoryLayout<GPUVertex>.stride * gpuVertices.count),
                  let indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt32>.stride * indices.count) else { continue }
            let model = Self.modelMatrix(node.transform)
            var uniforms = Uniforms(modelViewProjection: projection * viewMatrix * model, model: model)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func invalidateView() {
        #if os(macOS)
        view?.needsDisplay = true
        #else
        view?.setNeedsDisplay()
        #endif
    }

    private func activeCamera() -> (position: Vector3D, camera: Camera3D) {
        if let id = scene.activeCameraID,
           let node = scene.nodes.first(where: { $0.id == id }),
           case .camera(let camera) = node.payload {
            return (node.transform.position, camera)
        }
        return (Vector3D(x: 0, y: 0, z: 6), Camera3D())
    }

    private static func modelMatrix(_ transform: Transform3D) -> simd_float4x4 {
        let rx = rotationX(Float(transform.rotationDegrees.x * .pi / 180))
        let ry = rotationY(Float(transform.rotationDegrees.y * .pi / 180))
        let rz = rotationZ(Float(transform.rotationDegrees.z * .pi / 180))
        let scale = simd_float4x4(diagonal: SIMD4<Float>(Float(transform.scale.x), Float(transform.scale.y), Float(transform.scale.z), 1))
        return translation(SIMD3<Float>(Float(transform.position.x), Float(transform.position.y), Float(transform.position.z))) * rz * ry * rx * scale
    }

    private static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0), SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0), SIMD4<Float>(t.x, t.y, t.z, 1)
        )
    }

    private static func rotationX(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0), SIMD4<Float>(0, c, s, 0),
            SIMD4<Float>(0, -s, c, 0), SIMD4<Float>(0, 0, 0, 1)
        )
    }

    private static func rotationY(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(
            SIMD4<Float>(c, 0, -s, 0), SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(s, 0, c, 0), SIMD4<Float>(0, 0, 0, 1)
        )
    }

    private static func rotationZ(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(
            SIMD4<Float>(c, s, 0, 0), SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0), SIMD4<Float>(0, 0, 0, 1)
        )
    }

    private static func perspective(fovYRadians: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(max(fovYRadians, 0.001) * 0.5)
        let x = y / max(aspect, 0.001)
        let z = far / (near - far)
        return simd_float4x4(
            SIMD4<Float>(x, 0, 0, 0), SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1), SIMD4<Float>(0, 0, z * near, 0)
        )
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct GPUVertex { float3 position; float3 normal; };
    struct Uniforms { float4x4 modelViewProjection; float4x4 model; };
    struct Varying { float4 position [[position]]; float3 normal; };
    vertex Varying vertex_main(const device GPUVertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]], uint id [[vertex_id]]) {
        Varying out;
        float4 p = float4(vertices[id].position, 1.0);
        out.position = u.modelViewProjection * p;
        out.normal = normalize((u.model * float4(vertices[id].normal, 0.0)).xyz);
        return out;
    }
    fragment float4 fragment_main(Varying in [[stage_in]]) {
        float3 light = normalize(float3(0.35, 0.65, 0.7));
        float diffuse = max(dot(normalize(in.normal), light), 0.0);
        float shade = 0.18 + diffuse * 0.82;
        return float4(float3(0.47, 0.50, 0.86) * shade, 1.0);
    }
    """
}
#endif
