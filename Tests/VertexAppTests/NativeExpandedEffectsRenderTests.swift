import CoreImage
import CoreGraphics
import Testing
import VertexProject
@testable import Vertex

@Test func expandedNativeEffectsRenderDefaultFrames() {
    #expect(NativeExpandedFrameEffectProcessor.expandedTypes.count == 74)

    let extent = CGRect(x: 0, y: 0, width: 96, height: 64)
    let base = CIImage(color: CIColor(red: 0.12, green: 0.42, blue: 0.82, alpha: 1)).cropped(to: extent)
    let highlight = CIImage(color: CIColor(red: 1, green: 0.72, blue: 0.18, alpha: 1))
        .cropped(to: CGRect(x: 18, y: 14, width: 38, height: 30))
    let input = highlight.composited(over: base)
    let context = CIContext(options: [.cacheIntermediates: false])
    let processor = NativeExpandedFrameEffectProcessor()
    var failures: [String] = []

    for type in NativeExpandedFrameEffectProcessor.expandedTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
        do {
            let effect = ProjectEffect.makeDefault(type)
            guard let output = try processor.filteredImage(effect: effect, input: input) else {
                failures.append("\(type.rawValue): no expanded renderer")
                continue
            }
            let cropped = output.cropped(to: extent)
            guard context.createCGImage(cropped, from: extent) != nil else {
                failures.append("\(type.rawValue): Core Image could not render output")
                continue
            }
        } catch {
            failures.append("\(type.rawValue): \(error.localizedDescription)")
        }
    }

    #expect(failures.isEmpty, "Expanded effect render failures: \(failures.joined(separator: " | "))")
}

@Test func expandedNativeSetPlusLegacyAndAIMatchesDeclaredCatalog() {
    let native = Set(ProjectEffectType.allCases.filter(\.isNativePixelEffect))
    #expect(native.count == 95)
    #expect(NativeExpandedFrameEffectProcessor.expandedTypes.isSubset(of: native))
    #expect(ProjectEffectType.allCases.count == 99)
}
