import CoreGraphics
import CoreImage
import Testing
import VertexCore
import VertexProject
@testable import Vertex

@Test func allV17EffectsRenderRealPixelsAtExactTime() {
    #expect(NativeV17FrameEffectProcessor.v17Types.count == 29)
    let extent = CGRect(x: 0, y: 0, width: 640, height: 360)
    let background = CIImage(color: CIColor(red: 0.06, green: 0.12, blue: 0.28, alpha: 1)).cropped(to: extent)
    let accent = CIImage(color: CIColor(red: 1, green: 0.42, blue: 0.12, alpha: 1))
        .cropped(to: CGRect(x: 90, y: 64, width: 260, height: 180))
    let input = accent.composited(over: background)
    let context = CIContext(options: [.cacheIntermediates: false])
    let processor = NativeV17FrameEffectProcessor()
    let time = RationalTime(value: 47, timescale: 30)
    var failures: [String] = []

    for type in NativeV17FrameEffectProcessor.v17Types.sorted(by: { $0.rawValue < $1.rawValue }) {
        do {
            let effect = ProjectEffect.makeDefault(type)
            guard let output = try processor.filteredImage(effect: effect, input: input, time: time) else {
                failures.append("\(type.rawValue): no V17 renderer")
                continue
            }
            let cropped = output.cropped(to: extent)
            guard let rendered = context.createCGImage(cropped, from: extent) else {
                failures.append("\(type.rawValue): Core Image could not render")
                continue
            }
            #expect(rendered.width == 640)
            #expect(rendered.height == 360)
        } catch {
            failures.append("\(type.rawValue): \(error.localizedDescription)")
        }
    }
    #expect(failures.isEmpty, "V17 render failures: \(failures.joined(separator: " | "))")
}

@Test func V17ParticleOutputIsDeterministicForSameExactTime() throws {
    let extent = CGRect(x: 0, y: 0, width: 320, height: 180)
    let input = CIImage(color: CIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)).cropped(to: extent)
    let effect = ProjectEffect.makeDefault(.vertexSparks)
    let processor = NativeV17FrameEffectProcessor()
    let time = RationalTime(value: 61, timescale: 30)
    let first = try #require(processor.filteredImage(effect: effect, input: input, time: time))
    let second = try #require(processor.filteredImage(effect: effect, input: input, time: time))
    let context = CIContext(options: [.cacheIntermediates: false])
    let a = try #require(context.pngRepresentation(of: first.cropped(to: extent), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
    let b = try #require(context.pngRepresentation(of: second.cropped(to: extent), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
    #expect(a == b)
}
