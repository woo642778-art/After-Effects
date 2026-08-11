import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject

struct NativeFrameEffectProcessor {
    private static let contextThreadKey = "com.vertex2.native-effects.ci-context"
    private static var context: CIContext {
        if let cached = Thread.current.threadDictionary[contextThreadKey] as? CIContext { return cached }
        let created = CIContext(options: [.cacheIntermediates: true])
        Thread.current.threadDictionary[contextThreadKey] = created
        return created
    }
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func process(_ request: CompositionEffectRequest) throws -> PortableImage {
        guard request.effect.type.isNativePixelEffect else {
            throw CompositionError.graphCompilationFailed("Native processor received a non-native effect: \(request.effect.type.rawValue).")
        }
        guard let input = CIImage(data: request.input.data) else {
            throw CompositionError.graphCompilationFailed("Native effect input is not a decodable image.")
        }
        let output = try filteredImage(effect: request.effect, input: input, exactTime: request.exactCompositionTime).cropped(to: input.extent)
        guard let data = Self.context.pngRepresentation(of: output, format: .RGBA8, colorSpace: Self.colorSpace, options: [:]) else {
            throw CompositionError.graphCompilationFailed("Native effect output could not be encoded as PNG.")
        }
        return try PortableImage(data: data, format: .png, pixelSize: request.input.pixelSize)
    }

    private func filteredImage(effect: ProjectEffect, input: CIImage, exactTime: RationalTime) throws -> CIImage {
        if let generated = try V17GPUFrameEffectProcessor().filteredImage(effect: effect, input: input, exactTime: exactTime) { return generated }
        if let expanded = try NativeExpandedFrameEffectProcessor().filteredImage(effect: effect, input: input) { return expanded }

        let filterName: String
        switch effect.type {
        case .gaussianBlur: filterName = "CIGaussianBlur"
        case .fastBoxBlur: filterName = "CIBoxBlur"
        case .directionalBlur: filterName = "CIMotionBlur"
        case .sharpen: filterName = "CISharpenLuminance"
        case .median: filterName = "CIMedianFilter"
        case .noiseReduction: filterName = "CINoiseReduction"
        case .exposure: filterName = "CIExposureAdjust"
        case .colorControls: filterName = "CIColorControls"
        case .hueAdjust: filterName = "CIHueAdjust"
        case .vibrance: filterName = "CIVibrance"
        case .gammaAdjust: filterName = "CIGammaAdjust"
        case .highlightShadow: filterName = "CIHighlightShadowAdjust"
        case .sepiaTone: filterName = "CISepiaTone"
        case .invert: filterName = "CIColorInvert"
        case .posterize: filterName = "CIColorPosterize"
        case .mosaic: filterName = "CIPixellate"
        case .findEdges: filterName = "CIEdges"
        case .glow: filterName = "CIBloom"
        case .vignette: filterName = "CIVignette"
        case .cartoon: filterName = "CIComicEffect"
        case .twirl: filterName = "CITwirlDistortion"
        case .depthMap, .cutout, .upscale, .restore:
            throw CompositionError.graphCompilationFailed("AI effects must use the AI effect backend.")
        default:
            throw CompositionError.graphCompilationFailed("Expanded native effect was not handled: \(effect.type.rawValue).")
        }

        guard let filter = CIFilter(name: filterName) else { throw CompositionError.graphCompilationFailed("Core Image filter is unavailable: \(filterName).") }
        filter.setValue(input, forKey: kCIInputImageKey)
        switch effect.type {
        case .gaussianBlur: filter.setValue(try scalar(effect, GaussianBlurParameterID.radius), forKey: kCIInputRadiusKey)
        case .fastBoxBlur: filter.setValue(try scalar(effect, FastBoxBlurParameterID.radius), forKey: kCIInputRadiusKey)
        case .directionalBlur:
            filter.setValue(try scalar(effect, DirectionalBlurParameterID.radius), forKey: kCIInputRadiusKey)
            filter.setValue(try scalar(effect, DirectionalBlurParameterID.angle) * .pi / 180, forKey: kCIInputAngleKey)
        case .sharpen: filter.setValue(try scalar(effect, SharpenParameterID.sharpness), forKey: kCIInputSharpnessKey)
        case .median: break
        case .noiseReduction:
            filter.setValue(try scalar(effect, NoiseReductionParameterID.noiseLevel), forKey: "inputNoiseLevel")
            filter.setValue(try scalar(effect, NoiseReductionParameterID.sharpness), forKey: kCIInputSharpnessKey)
        case .exposure: filter.setValue(try scalar(effect, ExposureEffectParameterID.stops), forKey: kCIInputEVKey)
        case .colorControls:
            filter.setValue(try scalar(effect, ColorControlsParameterID.brightness), forKey: kCIInputBrightnessKey)
            filter.setValue(try scalar(effect, ColorControlsParameterID.contrast), forKey: kCIInputContrastKey)
            filter.setValue(try scalar(effect, ColorControlsParameterID.saturation), forKey: kCIInputSaturationKey)
        case .hueAdjust: filter.setValue(try scalar(effect, HueAdjustParameterID.degrees) * .pi / 180, forKey: kCIInputAngleKey)
        case .vibrance: filter.setValue(try scalar(effect, VibranceParameterID.amount), forKey: kCIInputAmountKey)
        case .gammaAdjust: filter.setValue(try scalar(effect, GammaAdjustParameterID.power), forKey: "inputPower")
        case .highlightShadow:
            filter.setValue(try scalar(effect, HighlightShadowParameterID.highlights), forKey: "inputHighlightAmount")
            filter.setValue(try scalar(effect, HighlightShadowParameterID.shadows), forKey: "inputShadowAmount")
        case .sepiaTone: filter.setValue(try scalar(effect, SepiaToneParameterID.intensity), forKey: kCIInputIntensityKey)
        case .invert: break
        case .posterize: filter.setValue(try scalar(effect, PosterizeParameterID.levels), forKey: "inputLevels")
        case .mosaic:
            filter.setValue(try scalar(effect, MosaicParameterID.scale), forKey: kCIInputScaleKey)
            filter.setValue(CIVector(x: input.extent.midX, y: input.extent.midY), forKey: kCIInputCenterKey)
        case .findEdges: filter.setValue(try scalar(effect, FindEdgesParameterID.intensity), forKey: kCIInputIntensityKey)
        case .glow:
            filter.setValue(try scalar(effect, GlowParameterID.radius), forKey: kCIInputRadiusKey)
            filter.setValue(try scalar(effect, GlowParameterID.intensity), forKey: kCIInputIntensityKey)
        case .vignette:
            filter.setValue(try scalar(effect, VignetteParameterID.radius), forKey: kCIInputRadiusKey)
            filter.setValue(try scalar(effect, VignetteParameterID.intensity), forKey: kCIInputIntensityKey)
        case .cartoon: break
        case .twirl:
            filter.setValue(CIVector(x: input.extent.midX, y: input.extent.midY), forKey: kCIInputCenterKey)
            filter.setValue(try scalar(effect, TwirlParameterID.radius), forKey: kCIInputRadiusKey)
            filter.setValue(try scalar(effect, TwirlParameterID.angle) * .pi / 180, forKey: kCIInputAngleKey)
        case .depthMap, .cutout, .upscale, .restore: break
        default: break
        }
        guard let output = filter.outputImage else { throw CompositionError.graphCompilationFailed("Core Image filter produced no output: \(filterName).") }
        return output
    }

    private func scalar(_ effect: ProjectEffect, _ id: String) throws -> Double {
        guard case .scalar(let value)? = effect.parameter(id: id)?.value else {
            throw CompositionError.graphCompilationFailed("Native effect parameter is missing or has the wrong type: \(id).")
        }
        return value
    }
}
