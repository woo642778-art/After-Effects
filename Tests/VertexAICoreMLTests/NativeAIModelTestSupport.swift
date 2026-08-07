import Foundation
import Testing
import VertexAI
@testable import VertexAICoreML

#if canImport(CoreML) && canImport(CoreVideo)
import CoreML
import CoreVideo

func preparedAIModelRoot() -> URL? {
    guard let root = ProcessInfo.processInfo.environment["VERTEX_AI_MODEL_ROOT"] else { return nil }
    return URL(fileURLWithPath: root, isDirectory: true)
}

func preparedAIManifest(root: URL) throws -> AIModelManifest {
    let data = try Data(contentsOf: root.appendingPathComponent("AI_MODEL_MANIFEST.json"))
    return try JSONDecoder().decode(AIModelManifest.self, from: data).validated(requireConvertedDigests: true)
}

func syntheticBGRA(width: Int, height: Int) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferMetalCompatibilityKey: true
    ]
    #expect(CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        attributes as CFDictionary,
        &pixelBuffer
    ) == kCVReturnSuccess)
    let buffer = try #require(pixelBuffer)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    let base = try #require(CVPixelBufferGetBaseAddress(buffer))
    for y in 0..<height {
        let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
            let offset = x * 4
            row[offset] = UInt8((x * 173 + y * 31) % 256)
            row[offset + 1] = UInt8((x * 17 + y * 193) % 256)
            row[offset + 2] = UInt8((x * 83 + y * 47) % 256)
            row[offset + 3] = 255
        }
    }
    return buffer
}

func pixelVariance(_ buffer: CVPixelBuffer) throws -> Double {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        throw AIError.inferenceFailed("Test output pixel buffer is unreadable.")
    }
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    var values: [Double] = []
    values.reserveCapacity(width * height)
    for y in 0..<height {
        let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
            let offset = x * 4
            values.append((Double(row[offset]) + Double(row[offset + 1]) + Double(row[offset + 2])) / 3)
        }
    }
    let mean = values.reduce(0, +) / Double(values.count)
    return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
}
#endif
