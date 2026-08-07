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
