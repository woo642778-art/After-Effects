import CoreGraphics
import CoreImage
import Testing
import VertexCore
import VertexProject
@testable import Vertex

@Test func v17GPUProceduralEffectsRenderAndAreDeterministic() throws {
    let extent = CGRect(x: 0, y: 0, width: 320, height: 180)
    let input = CIImage(color: CIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)).cropped(to: extent)
    let processor = V17GPUFrameEffectProcessor()
    let types: [ProjectEffectType] = [
        .vertexParticleEmitter, .vertexParticleTrails, .vertexParticleBurst, .vertexParticleSnow,
        .vertexFractalNoise, .vertexTurbulenceField, .vertexProceduralGrid, .vertexProceduralRays,
        .vertexProceduralDots, .vertexPlasma, .vertexVoronoi, .vertexChecker, .vertexGradient, .vertexStarField
    ]
    let time = RationalTime(value: 5, timescale: 4)
    let context = CIContext(options: [.cacheIntermediates: false])

    for type in types {
        let effect = ProjectEffect.makeDefault(type)
        let first = try #require(processor.filteredImage(effect: effect, input: input, exactTime: time))
        let second = try #require(processor.filteredImage(effect: effect, input: input, exactTime: time))
        let a = try #require(context.pngRepresentation(of: first.cropped(to: extent), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let b = try #require(context.pngRepresentation(of: second.cropped(to: extent), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        #expect(a == b, "V17 effect must be deterministic: \(type.rawValue)")
    }
}
