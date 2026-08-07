import Foundation
import VertexAI

public struct UpscaleOutputPlan: Equatable, Sendable {
    public static let maximumDimension = 16_384

    public let sourceWidth: Int
    public let sourceHeight: Int
    public let nativeScale: Int
    public let nativeWidth: Int
    public let nativeHeight: Int
    public let finalWidth: Int
    public let finalHeight: Int

    public var requiresFinalResample: Bool {
        nativeWidth != finalWidth || nativeHeight != finalHeight
    }

    public static func resolve(
        sourceWidth: Int,
        sourceHeight: Int,
        recipe: UpscaleRecipe,
        nativeScale: Int
    ) throws -> UpscaleOutputPlan {
        _ = try recipe.validated()
        guard sourceWidth > 0, sourceHeight > 0, nativeScale > 0 else {
            throw AIError.invalidRecipe("Upscale source dimensions and native scale must be positive.")
        }

        let (nativeWidth, nativeWidthOverflow) = sourceWidth.multipliedReportingOverflow(by: nativeScale)
        let (nativeHeight, nativeHeightOverflow) = sourceHeight.multipliedReportingOverflow(by: nativeScale)
        guard !nativeWidthOverflow, !nativeHeightOverflow else {
            throw AIError.invalidRecipe("Upscale native output dimensions overflowed.")
        }

        let finalWidth: Int
        let finalHeight: Int
        if let targetWidth = recipe.targetWidth, let targetHeight = recipe.targetHeight {
            finalWidth = targetWidth
            finalHeight = targetHeight
        } else {
            finalWidth = Int((Double(sourceWidth) * recipe.scale).rounded())
            finalHeight = Int((Double(sourceHeight) * recipe.scale).rounded())
        }

        guard (1...maximumDimension).contains(finalWidth),
              (1...maximumDimension).contains(finalHeight),
              nativeWidth <= maximumDimension,
              nativeHeight <= maximumDimension else {
            throw AIError.unsupportedCapability(
                "Requested upscale dimensions exceed the validated Phase 7 limit of \(maximumDimension) pixels per axis."
            )
        }

        return UpscaleOutputPlan(
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            nativeScale: nativeScale,
            nativeWidth: nativeWidth,
            nativeHeight: nativeHeight,
            finalWidth: finalWidth,
            finalHeight: finalHeight
        )
    }
}

public enum UpscaleModelSelection {
    public static func modelID(for profile: UpscaleProfile) -> String? {
        switch profile {
        case .general:
            "realesrgan-x4v3-f16"
        case .animeGame:
            // Do not silently pretend the general model is an anime-specific model.
            // This becomes non-nil only after an anime/game checkpoint passes the
            // same redistribution, Core ML, memory, and output-quality gate.
            nil
        }
    }
}

#if canImport(CoreImage) && canImport(CoreML) && canImport(CoreVideo)
import CoreImage
@preconcurrency import CoreML
import CoreVideo

public final class UpscaleInferenceEngine: @unchecked Sendable {
    private let registry: AIModelRegistry
    private let context: CIContext

    public init(
        registry: AIModelRegistry,
        context: CIContext = CIContext(options: [.cacheIntermediates: false])
    ) {
        self.registry = registry
        self.context = context
    }

    public func infer(pixelBuffer: CVPixelBuffer, recipe: UpscaleRecipe) throws -> CVPixelBuffer {
        _ = try recipe.validated()
        guard let modelID = UpscaleModelSelection.modelID(for: recipe.profile) else {
            throw AIError.unsupportedCapability(
                "The Anime/Game profile is disabled until a dedicated offline checkpoint passes the Phase 7 license, Core ML, memory, and quality gates."
            )
        }
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        return try registry.withModel(for: modelID) { model in
            let geometry = try TiledSuperResolutionRunner.geometry(for: model)
            let plan = try UpscaleOutputPlan.resolve(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                recipe: recipe,
                nativeScale: geometry.nativeScale
            )
            return try TiledSuperResolutionRunner.run(
                source: pixelBuffer,
                model: model,
                plan: plan,
                overlap: recipe.tileOverlap,
                context: context
            )
        }
    }
}

struct TiledSuperResolutionGeometry: Equatable, Sendable {
    let inputWidth: Int
    let inputHeight: Int
    let outputWidth: Int
    let outputHeight: Int
    let nativeScale: Int
}

enum TiledSuperResolutionRunner {
    static func geometry(for model: MLModel) throws -> TiledSuperResolutionGeometry {
        let input = try AIImageTensorAdapter.inputShape(for: model)
        guard input.width == input.height else {
            throw AIError.unsupportedCapability("Phase 7 tiled super-resolution currently requires square model input.")
        }
        guard let outputDescription = model.modelDescription.outputDescriptionsByName.values.first,
              model.modelDescription.outputDescriptionsByName.count == 1 else {
            throw AIError.inferenceFailed("Expected exactly one super-resolution model output.")
        }

        let outputWidth: Int
        let outputHeight: Int
        switch outputDescription.type {
        case .image:
            guard let constraint = outputDescription.imageConstraint else {
                throw AIError.inferenceFailed("Super-resolution image output has no size constraint.")
            }
            outputWidth = constraint.pixelsWide
            outputHeight = constraint.pixelsHigh
        case .multiArray:
            guard let constraint = outputDescription.multiArrayConstraint else {
                throw AIError.inferenceFailed("Super-resolution multi-array output has no shape constraint.")
            }
            let shape = constraint.shape.map(\.intValue)
            guard shape.count == 4, shape[0] == 1, shape[1] == 3 else {
                throw AIError.inferenceFailed("Expected NCHW RGB super-resolution output; got \(shape).")
            }
            outputHeight = shape[2]
            outputWidth = shape[3]
        default:
            throw AIError.inferenceFailed("Super-resolution output must be image or NCHW multi-array.")
        }

        guard outputWidth > 0, outputHeight > 0,
              outputWidth % input.width == 0,
              outputHeight % input.height == 0 else {
            throw AIError.inferenceFailed("Super-resolution model output dimensions are incompatible with its input.")
        }
        let xScale = outputWidth / input.width
        let yScale = outputHeight / input.height
        guard xScale == yScale, xScale > 0 else {
            throw AIError.inferenceFailed("Super-resolution model must use one integer scale on both axes.")
        }
        return TiledSuperResolutionGeometry(
            inputWidth: input.width,
            inputHeight: input.height,
            outputWidth: outputWidth,
            outputHeight: outputHeight,
            nativeScale: xScale
        )
    }

    static func run(
        source: CVPixelBuffer,
        model: MLModel,
        plan: UpscaleOutputPlan,
        overlap: Int,
        context: CIContext
    ) throws -> CVPixelBuffer {
        let geometry = try geometry(for: model)
        guard geometry.nativeScale == plan.nativeScale else {
            throw AIError.inferenceFailed("Upscale output plan does not match the loaded model scale.")
        }
        let safeOverlap = min(overlap, max(0, geometry.inputWidth / 2 - 1))
        let tiles = try AITilePlanner.plan(
            width: plan.sourceWidth,
            height: plan.sourceHeight,
            tileSize: geometry.inputWidth,
            overlap: safeOverlap,
            scale: geometry.nativeScale
        )
        let destination = try makePixelBuffer(width: plan.finalWidth, height: plan.finalHeight)
        clear(destination, context: context)

        for tile in tiles {
            let input = try paddedInputTile(
                source: source,
                tile: tile,
                modelWidth: geometry.inputWidth,
                modelHeight: geometry.inputHeight,
                context: context
            )
            let provider = try AIImageTensorAdapter.prediction(model: model, pixelBuffer: input)
            let prediction = try predictionPixelBuffer(provider: provider)
            let predictionWidth = CVPixelBufferGetWidth(prediction)
            let predictionHeight = CVPixelBufferGetHeight(prediction)
            guard predictionWidth == geometry.outputWidth,
                  predictionHeight == geometry.outputHeight else {
                throw AIError.inferenceFailed(
                    "Super-resolution model produced \(predictionWidth)x\(predictionHeight), expected \(geometry.outputWidth)x\(geometry.outputHeight)."
                )
            }
            try render(
                prediction: prediction,
                tile: tile,
                nativeScale: geometry.nativeScale,
                nativeWidth: plan.nativeWidth,
                nativeHeight: plan.nativeHeight,
                destination: destination,
                finalWidth: plan.finalWidth,
                finalHeight: plan.finalHeight,
                context: context
            )
        }
        return destination
    }

    private static func predictionPixelBuffer(provider: MLFeatureProvider) throws -> CVPixelBuffer {
        for name in provider.featureNames.sorted() {
            guard let value = provider.featureValue(for: name) else { continue }
            if value.type == .image, let buffer = value.imageBufferValue {
                return buffer
            }
            if value.type == .multiArray, let array = value.multiArrayValue {
                return try AIImageTensorAdapter.rgbPixelBuffer(from: array)
            }
        }
        throw AIError.inferenceFailed("Super-resolution prediction contained no supported RGB output.")
    }

    private static func paddedInputTile(
        source: CVPixelBuffer,
        tile: AITile,
        modelWidth: Int,
        modelHeight: Int,
        context: CIContext
    ) throws -> CVPixelBuffer {
        let destination = try makePixelBuffer(width: modelWidth, height: modelHeight)
        let sourceWidth = CVPixelBufferGetWidth(source)
        let sourceHeight = CVPixelBufferGetHeight(source)
        let input = tile.inputRect
        let sourceBottomY = sourceHeight - input.y - input.height
        let sourceRect = CGRect(
            x: input.x,
            y: sourceBottomY,
            width: input.width,
            height: input.height
        )
        var image = CIImage(cvPixelBuffer: source)
            .cropped(to: sourceRect)
            .transformed(by: CGAffineTransform(translationX: -Double(input.x), y: -Double(sourceBottomY)))
        // Keep the source tile aligned to the top-left of the model canvas. If
        // the entire source dimension is smaller than the fixed model input,
        // edge-clamp padding avoids introducing a black seam.
        image = image.transformed(
            by: CGAffineTransform(translationX: 0, y: Double(modelHeight - input.height))
        )
        let targetRect = CGRect(x: 0, y: 0, width: modelWidth, height: modelHeight)
        image = image.clampedToExtent().cropped(to: targetRect)
        context.render(
            image,
            to: destination,
            bounds: targetRect,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return destination
    }

    private static func render(
        prediction: CVPixelBuffer,
        tile: AITile,
        nativeScale: Int,
        nativeWidth: Int,
        nativeHeight: Int,
        destination: CVPixelBuffer,
        finalWidth: Int,
        finalHeight: Int,
        context: CIContext
    ) throws {
        let crop = tile.cropRect
        let predictionHeight = CVPixelBufferGetHeight(prediction)
        let cropX = crop.x * nativeScale
        let cropTopY = crop.y * nativeScale
        let cropWidth = crop.width * nativeScale
        let cropHeight = crop.height * nativeScale
        let cropBottomY = predictionHeight - cropTopY - cropHeight
        guard cropX >= 0, cropBottomY >= 0,
              cropX + cropWidth <= CVPixelBufferGetWidth(prediction),
              cropBottomY + cropHeight <= predictionHeight else {
            throw AIError.inferenceFailed("Super-resolution tile crop exceeded prediction bounds.")
        }

        let native = tile.outputRect
        let finalX0 = Int((Double(native.x) * Double(finalWidth) / Double(nativeWidth)).rounded())
        let finalX1 = Int((Double(native.maxX) * Double(finalWidth) / Double(nativeWidth)).rounded())
        let finalTopY0 = Int((Double(native.y) * Double(finalHeight) / Double(nativeHeight)).rounded())
        let finalTopY1 = Int((Double(native.maxY) * Double(finalHeight) / Double(nativeHeight)).rounded())
        let destinationWidth = max(1, finalX1 - finalX0)
        let destinationHeight = max(1, finalTopY1 - finalTopY0)
        let destinationBottomY = finalHeight - finalTopY1

        var image = CIImage(cvPixelBuffer: prediction)
            .cropped(to: CGRect(x: cropX, y: cropBottomY, width: cropWidth, height: cropHeight))
            .transformed(by: CGAffineTransform(translationX: -Double(cropX), y: -Double(cropBottomY)))
        image = image.transformed(by: CGAffineTransform(
            scaleX: Double(destinationWidth) / Double(cropWidth),
            y: Double(destinationHeight) / Double(cropHeight)
        ))
        image = image.transformed(by: CGAffineTransform(
            translationX: Double(finalX0),
            y: Double(destinationBottomY)
        ))
        let destinationRect = CGRect(
            x: finalX0,
            y: destinationBottomY,
            width: destinationWidth,
            height: destinationHeight
        )
        context.render(
            image,
            to: destination,
            bounds: destinationRect,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }

    private static func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw AIError.inferenceFailed("Could not allocate \(width)x\(height) AI output buffer (\(status)).")
        }
        return buffer
    }

    private static func clear(_ buffer: CVPixelBuffer, context: CIContext) {
        let rect = CGRect(
            x: 0,
            y: 0,
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer)
        )
        context.render(CIImage(color: .black).cropped(to: rect), to: buffer, bounds: rect, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
}

#endif
