import Testing
@testable import VertexProject

@Test("V17 expands the executable catalog to 128 real effects")
func phase17ExecutableEffectCount() throws {
    #expect(ProjectEffectType.allCases.count == 128)
    #expect(ProjectEffectType.allCases.filter(\.isNativePixelEffect).count == 124)
    #expect(ProjectEffectDescriptorRegistry.all.count == 128)
    #expect(Set(ProjectEffectDescriptorRegistry.all.map(\.type)).count == 128)

    for type in ProjectEffectType.allCases {
        _ = try ProjectEffect.makeDefault(type).validated()
    }
}

@Test("V17 exposes a dedicated particles and procedural category")
func phase17ParticleCategoryExists() {
    #expect(ProjectEffectCategory.allCases.contains(.particlesAndProcedural))
    #expect(ProjectEffectCategory.particlesAndProcedural.displayName == "Particles & Procedural")
}
