import Foundation
import VertexAI
import VertexAICoreML

#if canImport(CoreVideo)
import CoreVideo

struct AIFrameTemporalState {
    var depth: DepthFrame?
    var mask: CutoutMaskFrame?

    mutating func reset() {
        depth = nil
        mask = nil
    }
}

struct AIProcessedFrame {
    let pixelBuffer: CVPixelBuffer
    let highPrecisionDepth: DepthFrame?
}

final class AIFrameProcessor: @unchecked Sendable {
    private let depthEngine: DepthInferenceEngine
    private let cutoutEngine: VisionCutoutEngine
    private let upscaleEngine: UpscaleInferenceEngine
    private let restorationEngine: RestorationInferenceEngine

    init(registry: AIModelRegistry) {
        depthEngine = DepthInferenceEngine(registry: registry)
        cutoutEngine = VisionCutoutEngine()
        upscaleEngine = UpscaleInferenceEngine(registry: registry)
        restorationEngine = RestorationInferenceEngine(registry: registry)
    }

    func process(
        source: CVPixelBuffer,
        recipe: AITaskRecipe,
        effectiveTier: AIQualityTier,
        temporalState: inout AIFrameTemporalState
    ) throws -> AIProcessedFrame {
        switch recipe {
        case .depth(let depthRecipe):
            let frame = try depthEngine.infer(
                pixelBuffer: source,
                recipe: depthRecipe,
                previousFrame: temporalState.depth
            )
            temporalState.depth = frame
            return AIProcessedFrame(
                pixelBuffer: try PixelBufferFactory.depthPreview(frame),
                highPrecisionDepth: frame
            )

        case .cutout(let cutoutRecipe):
            let mask = try cutoutEngine.infer(
                pixelBuffer: source,
                recipe: cutoutRecipe,
                previousFrame: temporalState.mask
            )
            temporalState.mask = mask
            return AIProcessedFrame(
                pixelBuffer: try PixelBufferFactory.applyingAlpha(mask, to: source),
                highPrecisionDepth: nil
            )

        case .upscale(let upscaleRecipe):
            return AIProcessedFrame(
                pixelBuffer: try upscaleEngine.infer(pixelBuffer: source, recipe: upscaleRecipe),
                highPrecisionDepth: nil
            )

        case .restoration(let restorationRecipe):
            return AIProcessedFrame(
                pixelBuffer: try restorationEngine.infer(
                    pixelBuffer: source,
                    recipe: restorationRecipe,
                    qualityTier: effectiveTier
                ),
                highPrecisionDepth: nil
            )
        }
    }
}

private enum PixelBufferFactory {
    static func depthPreview(_ depth: DepthFrame) throws -> CVPixelBuffer {
        let buffer = try makeBGRA(width: depth.width, height: depth.height)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw AIError.inferenceFailed("Depth preview buffer is unreadable.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<depth.height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<depth.width {
                let value = UInt8((min(max(depth.values[y * depth.width + x], 0), 1) * 255).rounded())
                let offset = x * 4
                row[offset] = value
                row[offset + 1] = value
                row[offset + 2] = value
                row[offset + 3] = 255
            }
        }
        return buffer
    }

    static func applyingAlpha(_ mask: CutoutMaskFrame, to source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard mask.width == width, mask.height == height,
              CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA else {
            throw AIError.inferenceFailed("Cutout alpha application requires an aligned BGRA source.")
        }
        let output = try makeBGRA(width: width, height: height)
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(output, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }
        guard let sourceBase = CVPixelBufferGetBaseAddress(source),
              let outputBase = CVPixelBufferGetBaseAddress(output) else {
            throw AIError.inferenceFailed("Cutout source/output pixels are unreadable.")
        }
        let sourceRowBytes = CVPixelBufferGetBytesPerRow(source)
        let outputRowBytes = CVPixelBufferGetBytesPerRow(output)
        for y in 0..<height {
            let sourceRow = sourceBase.advanced(by: y * sourceRowBytes).assumingMemoryBound(to: UInt8.self)
            let outputRow = outputBase.advanced(by: y * outputRowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                outputRow[offset] = sourceRow[offset]
                outputRow[offset + 1] = sourceRow[offset + 1]
                outputRow[offset + 2] = sourceRow[offset + 2]
                outputRow[offset + 3] = UInt8((mask.alpha[y * width + x] * 255).rounded())
            }
        }
        return output
    }

    static func makeBGRA(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw AIError.inferenceFailed("Could not allocate AI frame buffer (\(status)).")
        }
        return buffer
    }
}

#endif
