import CoreGraphics
import CoreImage
import Foundation
import VertexComposition
import VertexMedia
import VertexProject

struct NativeFrameEffectProcessor {
    /// CIContext is intentionally long-lived. Creating one for every slider sample/frame
    /// repeatedly rebuilds Core Image/Metal state and was the dominant interactive cost
    /// in the V15 native-effect path. CIContext is designed to be reused across renders.
    private static let context = CIContext(options: [.cacheIntermediates: true])
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func process(_ request: CompositionEffectRequest) throws -> PortableImage {
        guard request.effect.type.isNativePixelEffect else {
            throw CompositionError.graphCompilationFailed("Native processor received a non-native effect: \(request.effect.type.rawValue).")
        }
        guard let input = CIImage(data: request.input.data) else {
            throw CompositionError.graphCompilationFailed("Native effect input is not a decodable image.")
        }

        let output = try filteredImage(effect: request.effect, input: input).cropped(to: input.extent)
        guard let data = Self.context.pngRepresentation(
            of: output,
            format: .RGBA8,
            colorSpace: Self.colorSpace,
            options: [:]
        ) else {
            throw CompositionError.graphCompilationFailed("Native effect output could not be encoded as PNG.")
        }
        return try PortableImage(data: data, format: .png, pixelSize: request.input.pixelSize)
    }

    private func filteredImage(effect: ProjectEffect, input: CIImage) throws -> CIImage {
        let filterName: String
        switch effect.type {
        case .gaussianBlur: filterName = "CIGaussianBlur"
        case .sharpen: filterName = "CISharpenLuminance"
        case .exposure: filterName = "CIExposureAdjust"
        case .colorControls: filterName = "CIColorControls"
        case .hueAdjust: filterName = "CIHueAdjust"
        case .invert: filterName = "CIColorInvert"
        case .depthMap, .cutout, .upscale, .restore:
            throw CompositionError.graphCompilationFailed("AI effects must use the AI effect backend.")
        }

        guard let filter = CIFilter(name: filterName) else {
            throw CompositionError.graphCompilationFailed("Core Image filter is unavailable: \(filterName).")
        }
        filter.setValue(input, forKey: kCIInputImageKey)

        switch effect.type {
        case .gaussianBlur:
            filter.setValue(try scalar(effect, GaussianBlurParameterID.radius), forKey: kCIInputRadiusKey)
        case .sharpen:
            filter.setValue(try scalar(effect, SharpenParameterID.sharpness), forKey: kCIInputSharpnessKey)
        case .exposure:
            filter.setValue(try scalar(effect, ExposureEffectParameterID.stops), forKey: kCIInputEVKey)
        case .colorControls:
            filter.setValue(try scalar(effect, ColorControlsParameterID.brightness), forKey: kCIInputBrightnessKey)
            filter.setValue(try scalar(effect, ColorControlsParameterID.contrast), forKey: kCIInputContrastKey)
            filter.setValue(try scalar(effect, ColorControlsParameterID.saturation), forKey: kCIInputSaturationKey)
        case .hueAdjust:
            let degrees = try scalar(effect, HueAdjustParameterID.degrees)
            filter.setValue(degrees * .pi / 180, forKey: kCIInputAngleKey)
        case .invert:
            break
        case .depthMap, .cutout, .upscale, .restore:
            break
        }

        guard let output = filter.outputImage else {
            throw CompositionError.graphCompilationFailed("Core Image filter produced no output: \(filterName).")
        }
        return output
    }

    private func scalar(_ effect: ProjectEffect, _ id: String) throws -> Double {
        guard case .scalar(let value)? = effect.parameter(id: id)?.value else {
            throw CompositionError.graphCompilationFailed("Native effect parameter is missing or has the wrong type: \(id).")
        }
        return value
    }
}
