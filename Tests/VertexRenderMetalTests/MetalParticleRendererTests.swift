#if canImport(Metal)
import Metal
import Testing
import VertexProcedural
@testable import VertexRenderMetal

@Test func metalParticleRendererProducesDeterministicVisiblePixels() throws {
    let renderer = try MetalParticleRenderer()
    let states = [
        ParticleState(birthIndex: 1, position: .init(x: 0.25, y: 0.4), velocity: .zero, ageSeconds: 0.2, normalizedAge: 0.2, size: 0.08, opacity: 0.9),
        ParticleState(birthIndex: 2, position: .init(x: 0.65, y: 0.55), velocity: .zero, ageSeconds: 0.4, normalizedAge: 0.4, size: 0.05, opacity: 0.7)
    ]
    let style = ParticleRenderStyle(color: .init(red: 1, green: 0.72, blue: 0.28, alpha: 1), additive: true)
    let first = try renderer.render(states: states, width: 256, height: 144, style: style)
    let second = try renderer.render(states: states, width: 256, height: 144, style: style)

    let firstBytes = bytes(from: first)
    let secondBytes = bytes(from: second)
    #expect(firstBytes == secondBytes)
    let nonzeroAlpha = stride(from: 3, to: firstBytes.count, by: 4).contains { firstBytes[$0] > 0 }
    #expect(nonzeroAlpha)
}

private func bytes(from texture: any MTLTexture) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        texture.getBytes(
            buffer.baseAddress!,
            bytesPerRow: texture.width * 4,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )
    }
    return bytes
}
#endif
