import CoreImage
import CoreVideo
import Foundation
import UIKit
import VertexAI
import VertexAICoreML
import VertexCore
import VertexMedia
import VertexProject

extension ProjectEffect {
    func aiRecipeAndTier() throws -> (AITaskRecipe, AIQualityTier) {
        guard !type.isNativePixelEffect else {
            throw AIError.invalidRecipe("Native pixel effects do not use the AI inference backend.")
        }
        func scalar(_ id: String) throws -> Double {
            guard case .scalar(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing scalar parameter \(id).") }
            return value
        }
        func boolean(_ id: String) throws -> Bool {
            guard case .boolean(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing boolean parameter \(id).") }
            return value
        }
        func text(_ id: String) throws -> String {
            guard case .text(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing text parameter \(id).") }
            return value
        }
        func integer(_ id: String) throws -> Int {
            guard case .integer(let value)? = parameter(id: id)?.value else { throw AIError.invalidRecipe("Missing integer parameter \(id).") }
            return value
        }
        let qualityText: String
        switch type {
        case .depthMap: qualityText = try text(DepthMapParameterID.quality)
        case .cutout: qualityText = try text(CutoutParameterID.quality)
        case .upscale: qualityText = try text(UpscaleParameterID.quality)
        case .restore: qualityText = try text(RestorationParameterID.quality)
        default:
            throw AIError.invalidRecipe("Native pixel effects do not use the AI inference backend.")
        }
        let tier: AIQualityTier = qualityText == "preview" ? .preview : (qualityText == "quality" ? .maxQuality : .balanced)
        switch type {
        case .depthMap:
            return (.depth(DepthRecipe(
                invert: try boolean(DepthMapParameterID.invert),
                nearValue: Float(try scalar(DepthMapParameterID.near)),
                farValue: Float(try scalar(DepthMapParameterID.far)),
                smoothing: Float(try scalar(DepthMapParameterID.smoothing)),
                edgeRefinement: Float(try scalar(DepthMapParameterID.edgeRefinement)),
                temporalSmoothing: Float(try scalar(DepthMapParameterID.temporalSmoothing))
            )), tier)
        case .cutout:
            let mode = CutoutMode(rawValue: try text(CutoutParameterID.mode)) ?? .foregroundFast
            let prompts: [CutoutPrompt] = mode == .promptQuality ? [.point(x: try scalar(CutoutParameterID.promptX), y: try scalar(CutoutParameterID.promptY), foreground: true)] : []
            return (.cutout(CutoutRecipe(
                mode: mode, prompts: prompts,
                feather: Float(try scalar(CutoutParameterID.feather)),
                edgeCleanup: Float(try scalar(CutoutParameterID.edgeCleanup)),
                temporalSmoothing: Float(try scalar(CutoutParameterID.temporalSmoothing))
            )), tier)
        case .upscale:
            let profile = UpscaleProfile(rawValue: try text(UpscaleParameterID.profile)) ?? .general
            return (.upscale(UpscaleRecipe(profile: profile, scale: try scalar(UpscaleParameterID.scale), tileOverlap: try integer(UpscaleParameterID.tileOverlap))), tier)
        case .restore:
            return (.restoration(RestorationRecipe(
                denoise: Float(try scalar(RestorationParameterID.denoise)),
                deblur: Float(try scalar(RestorationParameterID.deblur)),
                artifactRemoval: Float(try scalar(RestorationParameterID.artifactRemoval)),
                detailRecovery: Float(try scalar(RestorationParameterID.detailRecovery)),
                faceRestoration: try boolean(RestorationParameterID.faceRestoration)
            )), tier)
        default:
            throw AIError.invalidRecipe("Native pixel effects do not use the AI inference backend.")
        }
    }
}

actor BundledAIFrameEffectBackend: AIFrameEffectBackend {
    private let environment: BundledAIEnvironment
    private let depth: DepthInferenceEngine
    private let cutout = VisionCutoutEngine()
    private let upscale: UpscaleInferenceEngine
    private let restoration: RestorationInferenceEngine
    private var previousDepth: [VertexID: DepthFrame] = [:]
    private var previousMask: [VertexID: CutoutMaskFrame] = [:]
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    init(environment: BundledAIEnvironment) {
        self.environment = environment
        depth = DepthInferenceEngine(registry: environment.registry)
        upscale = UpscaleInferenceEngine(registry: environment.registry)
        restoration = RestorationInferenceEngine(registry: environment.registry)
    }

    func infer(_ request: AIFrameEffectRequest) async throws -> PortableImage {
        try Task.checkCancellation()
        let (recipe, tier) = try request.effect.aiRecipeAndTier()
        let input = try pixelBuffer(from: request.input)
        let output: CVPixelBuffer
        switch recipe {
        case .depth(let value):
            let result = try depth.infer(pixelBuffer: input, recipe: value, previousFrame: previousDepth[request.effectID])
            previousDepth[request.effectID] = result
            output = try depthPreview(result)
        case .cutout(let value):
            let mask = try cutout.infer(pixelBuffer: input, recipe: value, previousFrame: previousMask[request.effectID])
            previousMask[request.effectID] = mask
            output = try applyingAlpha(mask, to: input)
        case .upscale(let value):
            output = try upscale.infer(pixelBuffer: input, recipe: value)
        case .restoration(let value):
            output = try restoration.infer(pixelBuffer: input, recipe: value, qualityTier: tier)
        }
        try Task.checkCancellation()
        return try portableImage(from: output)
    }

    private func pixelBuffer(from image: PortableImage) throws -> CVPixelBuffer {
        guard let uiImage = UIImage(data: image.data), let cgImage = uiImage.cgImage else {
            throw AIError.inferenceFailed("AI frame input is not a decodable image.")
        }
        let width = cgImage.width, height = cgImage.height
        let buffer = try makeBGRA(width: width, height: height)
        ciContext.render(CIImage(cgImage: cgImage), to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }

    private func portableImage(from buffer: CVPixelBuffer) throws -> PortableImage {
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let cg = ciContext.createCGImage(CIImage(cvPixelBuffer: buffer), from: CGRect(x: 0, y: 0, width: width, height: height)),
              let data = UIImage(cgImage: cg).pngData() else {
            throw AIError.inferenceFailed("AI frame output could not be encoded as PNG.")
        }
        return try PortableImage(data: data, format: .png, pixelSize: VertexSize(width: Double(width), height: Double(height)))
    }

    private func depthPreview(_ frame: DepthFrame) throws -> CVPixelBuffer {
        let buffer = try makeBGRA(width: frame.width, height: frame.height)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw AIError.inferenceFailed("Depth preview allocation failed.") }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<frame.height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<frame.width {
                let v = UInt8((min(max(frame.values[y * frame.width + x], 0), 1) * 255).rounded())
                let o = x * 4; row[o] = v; row[o+1] = v; row[o+2] = v; row[o+3] = 255
            }
        }
        return buffer
    }

    private func applyingAlpha(_ mask: CutoutMaskFrame, to source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
        guard mask.width == width, mask.height == height else { throw AIError.inferenceFailed("Cutout mask does not align to source.") }
        let output = try makeBGRA(width: width, height: height)
        CVPixelBufferLockBaseAddress(source, .readOnly); CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []); CVPixelBufferUnlockBaseAddress(source, .readOnly) }
        guard let src = CVPixelBufferGetBaseAddress(source), let dst = CVPixelBufferGetBaseAddress(output) else { throw AIError.inferenceFailed("Cutout pixels unavailable.") }
        let sr = CVPixelBufferGetBytesPerRow(source), dr = CVPixelBufferGetBytesPerRow(output)
        for y in 0..<height {
            let s = src.advanced(by: y*sr).assumingMemoryBound(to: UInt8.self), d = dst.advanced(by: y*dr).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width { let o=x*4; d[o]=s[o]; d[o+1]=s[o+1]; d[o+2]=s[o+2]; d[o+3]=UInt8((mask.alpha[y*width+x]*255).rounded()) }
        }
        return output
    }

    private func makeBGRA(width: Int, height: Int) throws -> CVPixelBuffer {
        var result: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true,
             kCVPixelBufferCGBitmapContextCompatibilityKey: true,
             kCVPixelBufferMetalCompatibilityKey: true,
             kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &result)
        guard status == kCVReturnSuccess, let result else { throw AIError.inferenceFailed("Could not allocate BGRA frame (\(status)).") }
        return result
    }
}
