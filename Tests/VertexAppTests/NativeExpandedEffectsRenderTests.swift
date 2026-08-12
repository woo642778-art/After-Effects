import CoreImage
import CoreGraphics
import Testing
import VertexProject
@testable import Vertex

@Test func expandedNativeEffectsRenderDefaultFrames() {
    let v16Types = NativeExpandedFrameEffectProcessor.expandedTypes.subtracting(V17GPUFrameEffectProcessor.supportedTypes)
    #expect(v16Types.count == 74)

    let extent = CGRect(x: 0, y: 0, width: 640, height: 360)
    let base = CIImage(color: CIColor(red: 0.12, green: 0.42, blue: 0.82, alpha: 1)).cropped(to: extent)
    let highlight = CIImage(color: CIColor(red: 1, green: 0.72, blue: 0.18, alpha: 1))
        .cropped(to: CGRect(x: 120, y: 80, width: 250, height: 170))
    let input = highlight.composited(over: base)
    let context = CIContext(options: [.cacheIntermediates: false])
    let processor = NativeExpandedFrameEffectProcessor()
    var failures: [String] = []

    for type in v16Types.sorted(by: { $0.rawValue < $1.rawValue }) {
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
    #expect(native.count == 109)
    #expect(NativeExpandedFrameEffectProcessor.expandedTypes.isSubset(of: native))
    #expect(ProjectEffectType.allCases.count == 113)
}
