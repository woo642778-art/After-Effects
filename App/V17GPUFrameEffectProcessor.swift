import CoreGraphics
import CoreImage
import Foundation
import Metal
import VertexCore
import VertexProject

enum V17GPUFrameEffectError: LocalizedError {
    case metalUnavailable
    case libraryCompilation(String)
    case pipelineCreation
    case textureCreation
    case commandCreation
    case renderFailed
    case parameter(String)

    var errorDescription: String? {
        switch self {
        case .metalUnavailable: "Metal is unavailable for V17 GPU effects."
        case .libraryCompilation(let message): "V17 Metal library compilation failed: \(message)"
        case .pipelineCreation: "V17 Metal pipeline could not be created."
        case .textureCreation: "V17 GPU texture could not be created."
        case .commandCreation: "V17 GPU command buffer could not be created."
        case .renderFailed: "V17 GPU effect failed to render."
        case .parameter(let id): "V17 effect parameter is missing or invalid: \(id)."
        }
    }
}

/// Deterministic GPU generator for Vertex2 17 particle and procedural effects.
/// The kernel is a clean-room Vertex implementation and depends only on effect
/// parameters, exact composition time and seed, preserving preview/export parity.
struct V17GPUFrameEffectProcessor {
    static let supportedTypes: Set<ProjectEffectType> = [
        .vertexParticleEmitter, .vertexParticleTrails, .vertexParticleBurst, .vertexParticleSnow,
        .vertexFractalNoise, .vertexTurbulenceField, .vertexProceduralGrid, .vertexProceduralRays,
        .vertexProceduralDots, .vertexPlasma, .vertexVoronoi, .vertexChecker, .vertexGradient, .vertexStarField
    ]

    private static let rendererThreadKey = "com.vertex2.v17-gpu-renderer"
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func filteredImage(effect: ProjectEffect, input: CIImage, exactTime: RationalTime) throws -> CIImage? {
        guard Self.supportedTypes.contains(effect.type) else { return nil }
        let width = max(1, Int(input.extent.width.rounded(.up)))
        let height = max(1, Int(input.extent.height.rounded(.up)))
        let renderer = try Self.renderer()
        let mode = try modeIndex(effect.type)
        let values = try parameters(effect: effect, mode: mode, time: exactTime.seconds)
        let generated = try renderer.render(width: width, height: height, values: values)
            .transformed(by: CGAffineTransform(translationX: input.extent.minX, y: input.extent.minY))
            .cropped(to: input.extent)
        return generated.composited(over: input)
    }

    private static func renderer() throws -> Renderer {
        if let existing = Thread.current.threadDictionary[rendererThreadKey] as? Renderer { return existing }
        let created = try Renderer()
        Thread.current.threadDictionary[rendererThreadKey] = created
        return created
    }

    private func modeIndex(_ type: ProjectEffectType) throws -> Int {
        let ordered: [ProjectEffectType] = [
            .vertexParticleEmitter, .vertexParticleTrails, .vertexParticleBurst, .vertexParticleSnow,
            .vertexFractalNoise, .vertexTurbulenceField, .vertexProceduralGrid, .vertexProceduralRays,
            .vertexProceduralDots, .vertexPlasma, .vertexVoronoi, .vertexChecker, .vertexGradient, .vertexStarField
        ]
        guard let index = ordered.firstIndex(of: type) else { throw V17GPUFrameEffectError.renderFailed }
        return index
    }

    /// Layout: mode,time,seed,intensity,size,speed,gravity,turbulence,density,scale,angle,hue,centerX,centerY,lifetime,birthRate
    private func parameters(effect: ProjectEffect, mode: Int, time: Double) throws -> [Float] {
        func scalar(_ id: String, fallback: Double) throws -> Float {
            guard let parameter = effect.parameter(id: id) else { return Float(fallback) }
            guard case .scalar(let value) = parameter.value, value.isFinite else { throw V17GPUFrameEffectError.parameter(id) }
            return Float(value)
        }
        return [
            Float(mode), Float(time),
            try scalar(ExpandedEffectParameterID.seed, fallback: 17),
            try scalar(ExpandedEffectParameterID.intensity, fallback: 0.8),
            try scalar(ExpandedEffectParameterID.size, fallback: 7),
            try scalar(ExpandedEffectParameterID.speed, fallback: 0.24),
            try scalar(ExpandedEffectParameterID.gravity, fallback: 0.12),
            try scalar(ExpandedEffectParameterID.turbulence, fallback: 0.2),
            try scalar(ExpandedEffectParameterID.density, fallback: 0.55),
            try scalar(ExpandedEffectParameterID.scale, fallback: 24),
            try scalar(ExpandedEffectParameterID.angle, fallback: 0),
            try scalar(ExpandedEffectParameterID.hue, fallback: 0.58),
            try scalar(ExpandedEffectParameterID.centerX, fallback: 0.5),
            try scalar(ExpandedEffectParameterID.centerY, fallback: 0.5),
            try scalar(ExpandedEffectParameterID.lifetime, fallback: 3.2),
            try scalar(ExpandedEffectParameterID.birthRate, fallback: 52)
        ]
    }

    private final class Renderer {
        private let device: MTLDevice
        private let queue: MTLCommandQueue
        private let pipeline: MTLComputePipelineState

        init() throws {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
                throw V17GPUFrameEffectError.metalUnavailable
            }
            self.device = device
            self.queue = queue
            do {
                let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
                guard let function = library.makeFunction(name: "vertexV17Generate") else { throw V17GPUFrameEffectError.pipelineCreation }
                pipeline = try device.makeComputePipelineState(function: function)
            } catch let error as V17GPUFrameEffectError {
                throw error
            } catch {
                throw V17GPUFrameEffectError.libraryCompilation(error.localizedDescription)
            }
        }

        func render(width: Int, height: Int, values: [Float]) throws -> CIImage {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.shaderWrite, .shaderRead]
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor),
                  let buffer = queue.makeCommandBuffer(),
                  let encoder = buffer.makeComputeCommandEncoder() else {
                throw V17GPUFrameEffectError.commandCreation
            }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            var mutable = values
            encoder.setBytes(&mutable, length: MemoryLayout<Float>.stride * mutable.count, index: 0)
            let w = pipeline.threadExecutionWidth
            let h = max(1, pipeline.maxTotalThreadsPerThreadgroup / w)
            encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
            encoder.endEncoding()
            buffer.commit(); buffer.waitUntilCompleted()
            guard buffer.status == .completed,
                  let image = CIImage(mtlTexture: texture, options: [.colorSpace: V17GPUFrameEffectProcessor.colorSpace]) else {
                throw V17GPUFrameEffectError.renderFailed
            }
            return image
        }

        private static let shaderSource = #"""
#include <metal_stdlib>
using namespace metal;

float hash11(float p) { return fract(sin(p * 127.1f + 311.7f) * 43758.5453123f); }
float hash21(float2 p) { return fract(sin(dot(p, float2(127.1f,311.7f))) * 43758.5453123f); }
float2 hash22(float2 p) {
    float n = sin(dot(p, float2(41.0f,289.0f)));
    return fract(float2(262144.0f,32768.0f) * n);
}
float noise2(float2 p) {
    float2 i = floor(p), f = fract(p); f = f*f*(3.0f-2.0f*f);
    return mix(mix(hash21(i), hash21(i+float2(1,0)), f.x), mix(hash21(i+float2(0,1)), hash21(i+float2(1,1)), f.x), f.y);
}
float fbm(float2 p) {
    float s=0.0f, a=0.5f;
    for(int i=0;i<5;i++){ s += a*noise2(p); p=p*2.03f+17.13f; a*=0.5f; }
    return s;
}
float3 hsv2rgb(float3 c) {
    float3 p = abs(fract(c.xxx + float3(0.0f,2.0f/3.0f,1.0f/3.0f))*6.0f-3.0f);
    return c.z * mix(float3(1.0f), clamp(p-1.0f,0.0f,1.0f), c.y);
}
float circle(float2 uv, float2 c, float radius) { return smoothstep(radius, radius*0.38f, distance(uv,c)); }

kernel void vertexV17Generate(texture2d<float, access::write> outTex [[texture(0)]], constant float *p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    uint W=outTex.get_width(), H=outTex.get_height(); if(gid.x>=W||gid.y>=H) return;
    float2 uv=(float2(gid)+0.5f)/float2(W,H); float aspect=float(W)/max(1.0f,float(H));
    int mode=int(p[0]+0.5f); float t=p[1], seed=p[2], intensity=p[3], size=p[4]/max(1.0f,float(H));
    float speed=p[5], gravity=p[6], turb=p[7], density=p[8], scale=max(1.0f,p[9]);
    float angle=radians(p[10]), hue=p[11], cx=p[12], cy=p[13], life=max(0.2f,p[14]), rate=max(1.0f,p[15]);
    float3 col=float3(0); float alpha=0.0f; float2 q=float2((uv.x-cx)*aspect, uv.y-cy);

    if(mode<=3){
        int count=min(96,max(12,int(rate*density)));
        for(int i=0;i<count;i++){
            float fi=float(i); float r0=hash11(seed+fi*7.13f); float r1=hash11(seed+fi*13.71f); float r2=hash11(seed+fi*29.17f);
            float age=fract(t/life + r0)*life; float2 pos=float2(cx,cy); float2 vel=float2(cos(angle),sin(angle))*speed;
            if(mode==2){ float a=r1*6.2831853f; vel=float2(cos(a)/aspect,sin(a))*speed*(0.45f+0.9f*r2); }
            else if(mode==3){ pos=float2(r1, -0.05f+r2*0.15f); vel=float2((r0-0.5f)*0.045f, speed*0.28f); }
            else { pos += float2((r1-0.5f)*0.09f/aspect,(r2-0.5f)*0.09f); }
            float wob=sin((age*2.3f+r2*9.0f)+seed)*turb;
            pos += vel*age + float2(wob*0.025f/aspect, gravity*age*age*0.045f);
            if(mode==3) pos.y=fract(pos.y+age*0.08f);
            pos.x=1.0f-abs(fract(pos.x*0.5f)*2.0f-1.0f); pos.y=1.0f-abs(fract(pos.y*0.5f)*2.0f-1.0f);
            float fade=smoothstep(life,life*0.65f,age)*smoothstep(0.0f,0.08f,age);
            float a=circle(float2(uv.x*aspect,uv.y),float2(pos.x*aspect,pos.y),size*(0.6f+r2*1.2f))*fade;
            if(mode==1){ for(int j=1;j<=4;j++){ float ta=max(0.0f,age-float(j)*0.08f); float2 trail=pos-vel*(age-ta); a+=circle(float2(uv.x*aspect,uv.y),float2(trail.x*aspect,trail.y),size*0.65f)*fade*0.18f; } }
            float3 pc=hsv2rgb(float3(fract(hue+r1*0.16f),0.48f,1.0f)); col+=pc*a; alpha+=a;
        }
        alpha=clamp(alpha*intensity,0.0f,0.92f); col=clamp(col*intensity,0.0f,1.0f);
    } else if(mode==4 || mode==5){
        float n= mode==4 ? fbm(uv*scale+float2(t*0.08f,seed)) : abs(fbm(uv*scale+seed)-fbm(uv.yx*scale*1.37f-seed+t*0.12f));
        col=hsv2rgb(float3(fract(hue+n*0.18f),0.42f,n)); alpha=clamp(n*intensity*0.72f,0.0f,0.9f);
    } else if(mode==6){
        float2 r=abs(fract((uv-float2(cx,cy))*scale+0.5f)-0.5f); float line=1.0f-smoothstep(0.015f,0.055f,min(r.x,r.y)); col=hsv2rgb(float3(hue,0.35f,1)); alpha=line*intensity*0.75f;
    } else if(mode==7){
        float a=atan2(q.y,q.x)+angle; float ray=pow(max(0.0f,sin(a*scale+t*0.3f)),8.0f); float fall=exp(-length(q)*1.8f); col=hsv2rgb(float3(hue,0.35f,1)); alpha=ray*fall*intensity;
    } else if(mode==8){
        float2 cell=fract(uv*scale)-0.5f; float dot=1.0f-smoothstep(0.12f,0.34f,length(cell)); col=hsv2rgb(float3(hue,0.45f,1)); alpha=dot*intensity*0.82f;
    } else if(mode==9){
        float v=sin((uv.x*scale+t)*1.7f)+sin((uv.y*scale-t*0.7f)*2.1f)+sin((uv.x+uv.y)*scale*1.15f+t*0.6f); v=0.5f+0.5f*sin(v+seed); col=hsv2rgb(float3(fract(hue+v*0.28f),0.62f,0.85f+0.15f*v)); alpha=clamp(intensity*0.62f,0,0.9f);
    } else if(mode==10){
        float2 g=uv*scale, id=floor(g), f=fract(g); float md=10.0f;
        for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++){ float2 o=float2(x,y); float2 h=hash22(id+o+seed); md=min(md,length(o+h-f)); }
        float edge=1.0f-smoothstep(0.02f,0.13f,md); col=hsv2rgb(float3(fract(hue+md*0.22f),0.48f,0.75f+edge*0.25f)); alpha=clamp((0.28f+edge*0.5f)*intensity,0,0.88f);
    } else if(mode==11){
        float2 cell=floor(uv*scale); float c=fmod(cell.x+cell.y,2.0f); col=hsv2rgb(float3(fract(hue+c*0.12f),0.35f,0.7f+0.3f*c)); alpha=clamp(intensity*0.58f,0,0.86f);
    } else if(mode==12){
        float a=clamp((cos(angle)*q.x+sin(angle)*q.y)+0.5f,0.0f,1.0f); col=hsv2rgb(float3(fract(hue+a*0.18f),0.48f,0.55f+0.45f*a)); alpha=clamp(intensity*0.66f,0,0.9f);
    } else {
        float2 cell=floor(uv*scale*1.7f); float h=hash21(cell+seed); float2 star=(cell+hash22(cell+seed))/(scale*1.7f); float d=distance(uv,star); float twinkle=0.65f+0.35f*sin(t*2.0f+h*20.0f); float s=(h>1.0f-density*0.18f)?(1.0f-smoothstep(size*0.25f,size*1.4f,d))*twinkle:0.0f; col=hsv2rgb(float3(fract(hue+h*0.15f),0.2f,1)); alpha=clamp(s*intensity,0,0.95f);
    }
    outTex.write(float4(col*alpha,alpha),gid);
}
"""#
    }
}