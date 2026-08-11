import Testing
@testable import VertexProject

@Test("V17 expands the executable catalog to 113 effects")
func v17ExecutableCatalogCount() throws {
    #expect(ProjectEffectType.allCases.count == 113)
    #expect(ProjectEffectDescriptorRegistry.all.count == 113)
    #expect(ProjectEffectType.allCases.filter(\.isNativePixelEffect).count == 109)
    for type in ProjectEffectType.allCases {
        _ = try ProjectEffect.makeDefault(type).validated()
    }
}

@Test("V17 particle and procedural effects expose real animatable controls")
func v17ParticleAndProceduralDescriptors() {
    let expected: [ProjectEffectType] = [
        .vertexParticleEmitter, .vertexParticleTrails, .vertexParticleBurst, .vertexParticleSnow,
        .vertexFractalNoise, .vertexTurbulenceField, .vertexProceduralGrid, .vertexProceduralRays,
        .vertexProceduralDots, .vertexPlasma, .vertexVoronoi, .vertexChecker, .vertexGradient, .vertexStarField
    ]
    #expect(expected.count == 14)
    for type in expected {
        let descriptor = type.descriptor
        #expect(descriptor.executionMode == .nativePixel)
        #expect(!descriptor.parameters.isEmpty)
        #expect(descriptor.parameters.contains { $0.animatableKind != nil })
    }
}
