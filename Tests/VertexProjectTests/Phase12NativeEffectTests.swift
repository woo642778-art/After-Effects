import Testing
@testable import VertexProject

@Test("Vertex2 12 native effects expose validated typed defaults")
func phase12NativeEffectDefaultsValidate() throws {
    let nativeTypes: [ProjectEffectType] = [
        .gaussianBlur, .sharpen, .exposure, .colorControls, .hueAdjust, .invert
    ]
    for type in nativeTypes {
        let effect = ProjectEffect.makeDefault(type)
        #expect(effect.type == type)
        #expect(effect.type.isNativePixelEffect)
        _ = try effect.validated()
    }
}

@Test("Native effect parameter ranges reject invalid values")
func phase12NativeEffectRangesRejectInvalidValues() throws {
    var blur = ProjectEffect.makeDefault(.gaussianBlur)
    #expect(throws: ProjectError.self) {
        try blur.setParameter(id: GaussianBlurParameterID.radius, value: .scalar(201))
    }

    var exposure = ProjectEffect.makeDefault(.exposure)
    #expect(throws: ProjectError.self) {
        try exposure.setParameter(id: ExposureEffectParameterID.stops, value: .scalar(-11))
    }

    var color = ProjectEffect.makeDefault(.colorControls)
    try color.setParameter(id: ColorControlsParameterID.contrast, value: .scalar(2.25))
    #expect(color.parameter(id: ColorControlsParameterID.contrast)?.value == .scalar(2.25))
}
