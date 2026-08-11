import CoreImage
import CoreGraphics
import Testing
import VertexProject
@testable import Vertex

@Test func expandedNativeEffectsRenderDefaultFrames() throws {
    #expect(NativeExpandedFrameEffectProcessor.expandedTypes.count == 74)

    let extent = CGRect(x: 0, y: 0, width: 96, height: 64)
    let base = CIImage(color: CIColor(red: 0.12, green: 0.42, blue: 0.82, alpha: 1)).cropped(to: extent)
    let highlight = CIImage(color: CIColor(red: 1, green: 0.72, blue: 0.18, alpha: 1))
        .cropped(to: CGRect(x: 18, y: 14, width: 38, height: 30))
    let input = highlight.composited(over: base)
    let context = CIContext(options: [.cacheIntermediates: false])
    let processor = NativeExpandedFrameEffectProcessor()

    for type in NativeExpandedFrameEffectProcessor.expandedTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
        let effect = ProjectEffect.makeDefault(type)
        let output = try #require(processor.filteredImage(effect: effect, input: input), "No expanded renderer for \(type.rawValue)")
        let cropped = output.cropped(to: extent)
        let rendered = context.createCGImage(cropped, from: extent)
        #expect(rendered != nil, "Core Image could not render \(type.rawValue)")
    }
}

@Test func expandedNativeSetPlusLegacyAndAIMatchesDeclaredCatalog() {
    let native = Set(ProjectEffectType.allCases.filter(\.isNativePixelEffect))
    #expect(native.count == 95)
    #expect(NativeExpandedFrameEffectProcessor.expandedTypes.isSubset(of: native))
    #expect(ProjectEffectType.allCases.count == 99)
}
