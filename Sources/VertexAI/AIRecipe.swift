import Foundation

public struct DepthRecipe: Codable, Equatable, Sendable {
    public var invert: Bool
    public var nearValue: Float
    public var farValue: Float
    public var smoothing: Float
    public var edgeRefinement: Float
    public var temporalSmoothing: Float

    public init(
        invert: Bool = false,
        nearValue: Float = 0,
        farValue: Float = 1,
        smoothing: Float = 0,
        edgeRefinement: Float = 0,
        temporalSmoothing: Float = 0
    ) {
        self.invert = invert
        self.nearValue = nearValue
        self.farValue = farValue
        self.smoothing = smoothing
        self.edgeRefinement = edgeRefinement
        self.temporalSmoothing = temporalSmoothing
    }

    public func validated() throws -> Self {
        let values = [nearValue, farValue, smoothing, edgeRefinement, temporalSmoothing]
        guard values.allSatisfy(\.isFinite), nearValue < farValue,
              (0...1).contains(smoothing), (0...1).contains(edgeRefinement),
              (0...1).contains(temporalSmoothing) else {
            throw AIError.invalidRecipe("Depth values must be finite, near < far, and strengths within 0...1.")
        }
        return self
    }
}

public struct NormalizedPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func validated() throws -> Self {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
            throw AIError.invalidRecipe("Normalized points must be finite and inside 0...1.")
        }
        return self
    }
}

public enum CutoutMode: String, Codable, CaseIterable, Sendable {
    case personFast
    case foregroundFast
    case promptQuality
}

public enum CutoutPrompt: Codable, Equatable, Sendable {
    case point(x: Double, y: Double, foreground: Bool)
    case box(x: Double, y: Double, width: Double, height: Double)
    case brush(points: [NormalizedPoint], foreground: Bool)

    public func validated() throws -> Self {
        switch self {
        case .point(let x, let y, _):
            _ = try NormalizedPoint(x: x, y: y).validated()
        case .box(let x, let y, let width, let height):
            let values = [x, y, width, height]
            guard values.allSatisfy(\.isFinite), x >= 0, y >= 0,
                  width > 0, height > 0, x + width <= 1, y + height <= 1 else {
                throw AIError.invalidRecipe("Cutout boxes must be finite, positive, and remain inside normalized bounds.")
            }
        case .brush(let points, _):
            guard !points.isEmpty else { throw AIError.invalidRecipe("Cutout brush prompts must contain points.") }
            for point in points { _ = try point.validated() }
        }
        return self
    }
}

public struct CutoutRecipe: Codable, Equatable, Sendable {
    public var mode: CutoutMode
    public var prompts: [CutoutPrompt]
    public var feather: Float
    public var edgeCleanup: Float

    public init(mode: CutoutMode = .foregroundFast, prompts: [CutoutPrompt] = [], feather: Float = 0, edgeCleanup: Float = 0) {
        self.mode = mode
        self.prompts = prompts
        self.feather = feather
        self.edgeCleanup = edgeCleanup
    }

    public func validated() throws -> Self {
        guard feather.isFinite, edgeCleanup.isFinite,
              (0...1).contains(feather), (0...1).contains(edgeCleanup) else {
            throw AIError.invalidRecipe("Cutout feather and edge cleanup must be within 0...1.")
        }
        if mode == .promptQuality, prompts.isEmpty {
            throw AIError.invalidRecipe("Prompt Quality cutout requires at least one prompt.")
        }
        for prompt in prompts { _ = try prompt.validated() }
        return self
    }
}

public enum UpscaleProfile: String, Codable, CaseIterable, Sendable {
    case general
    case animeGame
}

public struct UpscaleRecipe: Codable, Equatable, Sendable {
    public var profile: UpscaleProfile
    public var scale: Double
    public var targetWidth: Int?
    public var targetHeight: Int?
    public var tileOverlap: Int

    public init(
        profile: UpscaleProfile = .general,
        scale: Double = 2,
        targetWidth: Int? = nil,
        targetHeight: Int? = nil,
        tileOverlap: Int = 32
    ) {
        self.profile = profile
        self.scale = scale
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.tileOverlap = tileOverlap
    }

    public func validated() throws -> Self {
        guard scale.isFinite, (1...4).contains(scale), tileOverlap >= 0, tileOverlap <= 256 else {
            throw AIError.invalidRecipe("Upscale scale must be 1...4 and overlap 0...256.")
        }
        if targetWidth != nil || targetHeight != nil {
            guard let targetWidth, let targetHeight,
                  (1...16384).contains(targetWidth), (1...16384).contains(targetHeight) else {
                throw AIError.invalidRecipe("Custom upscale output requires width and height within 1...16384.")
            }
        }
        return self
    }
}

public struct RestorationRecipe: Codable, Equatable, Sendable {
    public var denoise: Float
    public var deblur: Float
    public var artifactRemoval: Float
    public var detailRecovery: Float
    public var faceRestoration: Bool

    public init(
        denoise: Float = 0,
        deblur: Float = 0,
        artifactRemoval: Float = 0,
        detailRecovery: Float = 0,
        faceRestoration: Bool = false
    ) {
        self.denoise = denoise
        self.deblur = deblur
        self.artifactRemoval = artifactRemoval
        self.detailRecovery = detailRecovery
        self.faceRestoration = faceRestoration
    }

    public func validated() throws -> Self {
        let strengths = [denoise, deblur, artifactRemoval, detailRecovery]
        guard strengths.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw AIError.invalidRecipe("Restoration strengths must be finite and within 0...1.")
        }
        return self
    }
}

public enum AITaskRecipe: Codable, Equatable, Sendable {
    case depth(DepthRecipe)
    case cutout(CutoutRecipe)
    case upscale(UpscaleRecipe)
    case restoration(RestorationRecipe)

    public func validated() throws -> Self {
        switch self {
        case .depth(let recipe): _ = try recipe.validated()
        case .cutout(let recipe): _ = try recipe.validated()
        case .upscale(let recipe): _ = try recipe.validated()
        case .restoration(let recipe): _ = try recipe.validated()
        }
        return self
    }
}

public enum AIRecipeCodec {
    public static func canonicalData(_ recipe: AITaskRecipe) throws -> Data {
        _ = try recipe.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(recipe)
        } catch {
            throw AIError.invalidRecipe("Recipe could not be deterministically encoded: \(error.localizedDescription)")
        }
    }

    public static func digest(_ recipe: AITaskRecipe) throws -> String {
        StableAISHA256.hexDigest(try canonicalData(recipe))
    }
}
