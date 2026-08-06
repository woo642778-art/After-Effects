#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VertexCore
import VertexMedia
import VertexRender

internal struct DecodedRGBAImage: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]
}

internal enum MetalImageCodec {
    static func decode(_ image: PortableImage) throws -> DecodedRGBAImage {
        guard let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RenderError.unsupportedImage("ImageIO could not decode the source bytes.")
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            throw RenderError.unsupportedImage("The decoded image has invalid dimensions.")
        }

        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        let rendered = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .high
            context.setBlendMode(.copy)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else {
            throw RenderError.unsupportedImage("A normalized RGBA bitmap context could not be created.")
        }
        return DecodedRGBAImage(width: width, height: height, bytes: bytes)
    }

    static func encodePNG(
        bytes: [UInt8],
        width: Int,
        height: Int,
        color: ColorDescriptor
    ) throws -> PortableImage {
        guard bytes.count == width * height * 4 else {
            throw RenderError.outputEncodingFailure("RGBA byte count does not match the output dimensions.")
        }

        let colorSpace: CGColorSpace
        switch color.primaries {
        case .displayP3:
            colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        case .rec2020:
            colorSpace = CGColorSpace(name: CGColorSpace.itur_2020) ?? CGColorSpaceCreateDeviceRGB()
        default:
            colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw RenderError.outputEncodingFailure("A CGImage could not be created from the rendered bytes.")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw RenderError.outputEncodingFailure("A PNG destination could not be created.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError.outputEncodingFailure("ImageIO could not finalize the PNG output.")
        }

        return try PortableImage(
            data: output as Data,
            format: .png,
            pixelSize: VertexSize(width: Double(width), height: Double(height))
        )
    }
}
#endif
