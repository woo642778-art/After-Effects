import Foundation
import VertexAI

public struct CutoutMaskFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let alpha: [Float]

    public init(width: Int, height: Int, alpha: [Float]) throws {
        guard width > 0, height > 0, alpha.count == width * height,
              alpha.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw AIError.inferenceFailed("Cutout mask dimensions or alpha values are invalid.")
        }
        self.width = width
        self.height = height
        self.alpha = alpha
    }

    public func previewBytes() -> [UInt8] {
        alpha.map { UInt8(($0 * 255).rounded()) }
    }
}

public enum CutoutMaskProcessing {
    public static func process(
        alpha: [Float],
        width: Int,
        height: Int,
        recipe: CutoutRecipe,
        previous: CutoutMaskFrame? = nil
    ) throws -> CutoutMaskFrame {
        _ = try recipe.validated()
        guard width > 0, height > 0, alpha.count == width * height else {
            throw AIError.inferenceFailed("Cutout mask dimensions do not match alpha data.")
        }
        var result = alpha.map { value in value.isFinite ? min(max(value, 0), 1) : 0 }

        if recipe.edgeCleanup > 0 {
            let amount = recipe.edgeCleanup
            for index in result.indices {
                let value = result[index]
                let smooth = value * value * (3 - 2 * value)
                let cleaned = value < 0.5 ? smooth * (1 - amount) : 1 - (1 - smooth) * (1 - amount)
                result[index] = min(max(cleaned, 0), 1)
            }
        }

        if recipe.feather > 0 {
            let radius = max(1, Int((recipe.feather * 8).rounded()))
            result = boxBlur(result, width: width, height: height, radius: radius)
        }

        if recipe.temporalSmoothing > 0, let previous,
           previous.width == width, previous.height == height {
            let oldWeight = recipe.temporalSmoothing
            let newWeight = 1 - oldWeight
            for index in result.indices {
                result[index] = previous.alpha[index] * oldWeight + result[index] * newWeight
            }
        }

        return try CutoutMaskFrame(width: width, height: height, alpha: result)
    }

    private static func boxBlur(_ input: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard radius > 0 else { return input }
        var horizontal = Array(repeating: Float.zero, count: input.count)
        var output = Array(repeating: Float.zero, count: input.count)
        for y in 0..<height {
            for x in 0..<width {
                let low = max(0, x - radius), high = min(width - 1, x + radius)
                var sum: Float = 0
                for sx in low...high { sum += input[y * width + sx] }
                horizontal[y * width + x] = sum / Float(high - low + 1)
            }
        }
        for y in 0..<height {
            let low = max(0, y - radius), high = min(height - 1, y + radius)
            for x in 0..<width {
                var sum: Float = 0
                for sy in low...high { sum += horizontal[sy * width + x] }
                output[y * width + x] = sum / Float(high - low + 1)
            }
        }
        return output
    }
}

#if canImport(Vision) && canImport(CoreVideo)
import CoreVideo
@preconcurrency import Vision

public final class VisionCutoutEngine: @unchecked Sendable {
    public init() {}

    public func infer(
        pixelBuffer: CVPixelBuffer,
        recipe: CutoutRecipe,
        previousFrame: CutoutMaskFrame? = nil
    ) throws -> CutoutMaskFrame {
        _ = try recipe.validated()
        let rawMask: CVPixelBuffer
        switch recipe.mode {
        case .personFast:
            rawMask = try personMask(pixelBuffer: pixelBuffer)
        case .foregroundFast:
            rawMask = try foregroundMask(pixelBuffer: pixelBuffer, prompts: nil)
        case .promptQuality:
            rawMask = try foregroundMask(pixelBuffer: pixelBuffer, prompts: recipe.prompts)
        }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let alpha = try MaskPixelReader.normalizedAlpha(rawMask)
        let resized: [Float]
        if alpha.width == sourceWidth, alpha.height == sourceHeight {
            resized = alpha.values
        } else {
            resized = DepthProcessing.bilinearResize(
                alpha.values,
                sourceWidth: alpha.width,
                sourceHeight: alpha.height,
                targetWidth: sourceWidth,
                targetHeight: sourceHeight
            )
        }
        return try CutoutMaskProcessing.process(
            alpha: resized,
            width: sourceWidth,
            height: sourceHeight,
            recipe: recipe,
            previous: previousFrame
        )
    }

    private func personMask(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            throw AIError.inferenceFailed("Vision person segmentation failed: \(error.localizedDescription)")
        }
        guard let observation = request.results?.first else {
            throw AIError.inferenceFailed("Vision person segmentation returned no mask.")
        }
        return observation.pixelBuffer
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func foregroundMask(pixelBuffer: CVPixelBuffer, prompts: [CutoutPrompt]?) throws -> CVPixelBuffer {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            throw AIError.inferenceFailed("Vision foreground instance segmentation failed: \(error.localizedDescription)")
        }
        guard let observation = request.results?.first else {
            throw AIError.inferenceFailed("Vision foreground segmentation returned no instances.")
        }

        let selected: IndexSet
        if let prompts {
            selected = try PromptInstanceSelector.select(prompts: prompts, observation: observation)
        } else {
            selected = observation.allInstances
        }
        guard !selected.isEmpty else {
            throw AIError.inferenceFailed("No foreground instance matched the current cutout selection.")
        }
        do {
            return try observation.generateScaledMaskForImage(forInstances: selected, from: handler)
        } catch {
            throw AIError.inferenceFailed("Vision could not generate a high-resolution foreground mask: \(error.localizedDescription)")
        }
    }
}

private enum PromptInstanceSelector {
    @available(iOS 17.0, macOS 14.0, *)
    static func select(prompts: [CutoutPrompt], observation: VNInstanceMaskObservation) throws -> IndexSet {
        let labels = try MaskPixelReader.instanceLabels(observation.instanceMask)
        var selected = IndexSet()
        for prompt in prompts {
            switch prompt {
            case .point(let x, let y, let foreground):
                apply(labelAt(x: x, y: y, labels: labels), foreground: foreground, to: &selected)
            case .brush(let points, let foreground):
                for point in points {
                    apply(labelAt(x: point.x, y: point.y, labels: labels), foreground: foreground, to: &selected)
                }
            case .box(let x, let y, let width, let height):
                var counts: [Int: Int] = [:]
                let samples = 9
                for iy in 0..<samples {
                    for ix in 0..<samples {
                        let px = x + width * (Double(ix) + 0.5) / Double(samples)
                        let py = y + height * (Double(iy) + 0.5) / Double(samples)
                        if let label = labelAt(x: px, y: py, labels: labels), label > 0 {
                            counts[label, default: 0] += 1
                        }
                    }
                }
                for (label, count) in counts where count >= 2 { selected.insert(label) }
            }
        }
        return selected
    }

    private static func apply(_ label: Int?, foreground: Bool, to selection: inout IndexSet) {
        guard let label, label > 0 else { return }
        if foreground { selection.insert(label) } else { selection.remove(label) }
    }

    private static func labelAt(
        x: Double,
        y: Double,
        labels: (width: Int, height: Int, values: [Int])
    ) -> Int? {
        guard (0...1).contains(x), (0...1).contains(y) else { return nil }
        let pixelX = min(labels.width - 1, max(0, Int((x * Double(labels.width - 1)).rounded())))
        let pixelY = min(labels.height - 1, max(0, Int(((1 - y) * Double(labels.height - 1)).rounded())))
        return labels.values[pixelY * labels.width + pixelX]
    }
}

private enum MaskPixelReader {
    static func normalizedAlpha(_ buffer: CVPixelBuffer) throws -> (width: Int, height: Int, values: [Float]) {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let format = CVPixelBufferGetPixelFormatType(buffer)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw AIError.inferenceFailed("Vision mask has no readable pixel base address.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var values = Array(repeating: Float.zero, count: width * height)
        switch format {
        case kCVPixelFormatType_OneComponent8:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width { values[y * width + x] = Float(row[x]) / 255 }
            }
        case kCVPixelFormatType_OneComponent32Float:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
                for x in 0..<width { values[y * width + x] = min(max(row[x], 0), 1) }
            }
        case kCVPixelFormatType_32BGRA:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width { values[y * width + x] = Float(row[x * 4]) / 255 }
            }
        default:
            throw AIError.inferenceFailed("Unsupported Vision mask pixel format: \(format)")
        }
        return (width, height, values)
    }

    static func instanceLabels(_ buffer: CVPixelBuffer) throws -> (width: Int, height: Int, values: [Int]) {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let format = CVPixelBufferGetPixelFormatType(buffer)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw AIError.inferenceFailed("Vision instance mask has no readable base address.")
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var values = Array(repeating: 0, count: width * height)
        switch format {
        case kCVPixelFormatType_OneComponent8:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width { values[y * width + x] = Int(row[x]) }
            }
        case kCVPixelFormatType_OneComponent32Float:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
                for x in 0..<width { values[y * width + x] = Int(row[x].rounded()) }
            }
        default:
            throw AIError.inferenceFailed("Unsupported Vision instance-label pixel format: \(format)")
        }
        return (width, height, values)
    }
}

#endif
