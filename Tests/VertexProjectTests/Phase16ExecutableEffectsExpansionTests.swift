import Testing
import VertexProject

@Test func executableEffectExpansionRequiresOneHundredThirteenDeclaredEffects() throws {
    #expect(ProjectEffectType.allCases.count == 113)
    #expect(ProjectEffectDescriptorRegistry.all.count == 113)
    #expect(Set(ProjectEffectDescriptorRegistry.all.map(\.type)) == Set(ProjectEffectType.allCases))

    for type in ProjectEffectType.allCases {
        let effect = ProjectEffect.makeDefault(type)
        #expect(effect.type == type)
        _ = try effect.validated()
    }
}

@Test func executableEffectExpansionKeepsOnlyFourAIEffects() {
    let ai = ProjectEffectType.allCases.filter { !$0.isNativePixelEffect }
    #expect(Set(ai) == [.depthMap, .cutout, .upscale, .restore])
    #expect(ProjectEffectType.allCases.filter(\.isNativePixelEffect).count == 109)
}
