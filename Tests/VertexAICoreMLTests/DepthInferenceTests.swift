import Foundation
import Testing
import VertexAI
@testable import VertexAICoreML

@Test("Depth postprocessing normalizes finite nonconstant predictions")
func depthPostprocessingNormalizes() throws {
    let raw: [Float] = [0, 1, 2, 3, 4, 5]
    let frame = try DepthProcessing.process(
        values: raw,
        width: 3,
        height: 2,
        recipe: DepthRecipe()
    )
    #expect(frame.width == 3)
    #expect(frame.height == 2)
    #expect(frame.values.allSatisfy { $0.isFinite && (0...1).contains($0) })
    #expect(frame.minimum == 0)
    #expect(frame.maximum == 1)
    #expect(Set(frame.previewBytes()).count > 1)
}

@Test("Depth temporal smoothing blends with previous frame")
func depthTemporalSmoothing() throws {
    let previous = try DepthFrame(width: 2, height: 2, values: [0, 0, 0, 0])
    let current = try DepthProcessing.process(
        values: [0, 1, 2, 3],
        width: 2,
        height: 2,
        recipe: DepthRecipe(temporalSmoothing: 0.5),
        previous: previous
    )
    #expect(current.maximum == 0.5)
}

@Test("Constant depth output is rejected")
func constantDepthRejected() {
    #expect(throws: AIError.self) {
        _ = try DepthProcessing.process(
            values: [1, 1, 1, 1],
            width: 2,
            height: 2,
            recipe: DepthRecipe()
        )
    }
}

#if canImport(CoreML) && canImport(CoreVideo)
import CoreML
import CoreVideo

@Test("Bundled Depth Anything model performs real local inference when CI provides the model root")
func bundledDepthAnythingInference() throws {
    guard let rootPath = ProcessInfo.processInfo.environment["VERTEX_AI_MODEL_ROOT"] else { return }
    let root = URL(fileURLWithPath: rootPath, isDirectory: true)
    let compiled = root.appendingPathComponent("AIModels/DepthAnythingV2SmallF16.mlmodelc")
    guard FileManager.default.fileExists(atPath: compiled.path) else {
        Issue.record("VERTEX_AI_MODEL_ROOT was supplied but Depth Anything is missing")
        return
    }

    let manifest = AIModelManifest(models: [
        AIModelManifestEntry(
            modelID: DepthInferenceEngine.defaultModelID,
            task: "depth",
            upstream: "https://huggingface.co/apple/coreml-depth-anything-v2-small",
            upstreamVersion: "cfef6f6f2a70783dedc0bfae40cecbc2052285d3",
            license: "Apache-2.0",
            sourceSHA256: String(repeating: "a", count: 64),
            convertedSHA256: nil,
            precision: "float16",
            compiledSizeBytes: nil,
            minimumTier: .preview,
            bundleRelativePath: "AIModels/DepthAnythingV2SmallF16.mlmodelc"
        )
    ])
    let registry = try AIModelRegistry(resourceRoot: root, manifest: manifest)
    let engine = DepthInferenceEngine(registry: registry)

    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    #expect(CVPixelBufferCreate(kCFAllocatorDefault, 96, 64, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer) == kCVReturnSuccess)
    let buffer = try #require(pixelBuffer)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    let base = try #require(CVPixelBufferGetBaseAddress(buffer))
    for y in 0..<64 {
        let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<96 {
            let offset = x * 4
            row[offset] = UInt8((x * 255) / 95)
            row[offset + 1] = UInt8((y * 255) / 63)
            row[offset + 2] = UInt8(((x + y) * 255) / 158)
            row[offset + 3] = 255
        }
    }

    let depth = try engine.infer(pixelBuffer: buffer, recipe: DepthRecipe())
    #expect(depth.width == 96)
    #expect(depth.height == 64)
    #expect(depth.values.allSatisfy { $0.isFinite })
    #expect(depth.maximum > depth.minimum)
}
#endif
