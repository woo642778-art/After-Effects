#if canImport(Metal) && canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import VertexCore
import VertexMedia
import VertexRender
@testable import VertexRenderMetal

private func solidFixture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) throws -> PortableImage {
    let width = 2
    let height = 2
    let bytes = Array(repeating: [red, green, blue, alpha], count: width * height).flatMap { $0 }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          ) else {
        throw RenderError.outputEncodingFailure("Test fixture CGImage creation failed.")
    }
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RenderError.outputEncodingFailure("Test fixture PNG creation failed.")
    }
    return try PortableImage(
        data: data as Data,
        format: .png,
        pixelSize: VertexSize(width: 2, height: 2)
    )
}

private func pixel(_ data: Data, x: Int, y: Int) throws -> [UInt8] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          (0..<image.width).contains(x),
          (0..<image.height).contains(y) else {
        throw RenderError.unsupportedImage("Rendered fixture could not be decoded or the pixel coordinate is invalid.")
    }
    var bytes = Array(repeating: UInt8(0), count: image.width * image.height * 4)
    let succeeded = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard succeeded else { throw RenderError.unsupportedImage("Rendered fixture context failed.") }
    let offset = (y * image.width + x) * 4
    return Array(bytes[offset..<(offset + 4)])
}

private func metalRequest(invert: Bool, opacity: Double = 1) throws -> RenderRequest {
    let sourceID = VertexID(rawValue: "20000000-0000-0000-0000-000000000001")
    let operationID = VertexID(rawValue: "20000000-0000-0000-0000-000000000002")
    let outputID = VertexID(rawValue: "20000000-0000-0000-0000-000000000003")
    let graph = RenderGraph(nodes: [
        RenderNode(id: sourceID, dependencies: [], kind: .source(try solidFixture(red: 255, green: 0, blue: 0))),
        RenderNode(
            id: operationID,
            dependencies: [sourceID],
            kind: .operations([
                .transform(scale: 1, translationX: 0, translationY: 0),
                .exposure(stops: 0),
                .saturation(1),
                .invert(invert),
                .opacity(opacity)
            ])
        ),
        RenderNode(id: outputID, dependencies: [operationID], kind: .output)
    ])
    return try RenderRequest(
        graph: graph,
        time: .zero,
        output: RenderOutputSpecification(width: 4, height: 4)
    )
}

@Test("Metal backend renders requested dimensions and inversion")
func metalInversionAndDimensions() async throws {
    let backend = try MetalRenderBackend()
    let result = try await backend.render(
        metalRequest(invert: true),
        cancellationToken: RenderCancellationToken()
    )
    #expect(result.image.pixelSize == VertexSize(width: 4, height: 4))
    #expect(result.metrics.outputPixelCount == 16)

    let interiorPixel = try pixel(result.image.data, x: 1, y: 1)
    #expect(interiorPixel[0] < 16)
    #expect(interiorPixel[1] > 235)
    #expect(interiorPixel[2] > 235)
    #expect(interiorPixel[3] > 235)
}

@Test("Metal backend applies opacity to alpha")
func metalOpacity() async throws {
    let backend = try MetalRenderBackend()
    let result = try await backend.render(
        metalRequest(invert: false, opacity: 0.5),
        cancellationToken: RenderCancellationToken()
    )
    let interiorPixel = try pixel(result.image.data, x: 1, y: 1)
    #expect((115...140).contains(Int(interiorPixel[3])))
}
#endif
