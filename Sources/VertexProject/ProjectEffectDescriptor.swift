import Foundation
import VertexCore

public enum ProjectEffectCategory: String, CaseIterable, Sendable {
    case blurAndSharpen
    case colorCorrection
    case channel
    case stylize
    case distort
    case tile
    case keying
    case particlesAndProcedural
    case ai

    public var displayName: String {
        switch self {
        case .blurAndSharpen: "Blur & Sharpen"
        case .colorCorrection: "Color Correction"
        case .channel: "Channel"
        case .stylize: "Stylize"
        case .distort: "Distort"
        case .tile: "Tile"
        case .keying: "Keying"
        case .particlesAndProcedural: "Particles & Procedural"
        case .ai: "AI"
        }
    }
}

public enum ProjectEffectExecutionMode: String, CaseIterable, Sendable {
    case nativePixel
    case aiBake
}

public enum ProjectEffectParameterDomain: Equatable, Sendable {
    case scalar(ClosedRange<Double>)
    case integer(ClosedRange<Int>)
    case boolean
    case text(options: [String])

    public var animatableKind: ProjectAnimatableValueKind? {
        switch self {
        case .scalar: .scalar
        case .boolean: .boolean
        case .integer, .text: nil
        }
    }

    public var scalarRange: ClosedRange<Double>? {
        guard case .scalar(let range) = self else { return nil }
        return range
    }

    public var integerRange: ClosedRange<Int>? {
        guard case .integer(let range) = self else { return nil }
        return range
    }

    public var textOptions: [String]? {
        guard case .text(let options) = self else { return nil }
        return options
    }

    public func validate(_ value: ProjectEffectParameterValue, id: String) throws {
        switch (self, value) {
        case (.scalar(let range), .scalar(let scalar)) where scalar.isFinite && range.contains(scalar): return
        case (.integer(let range), .integer(let integer)) where range.contains(integer): return
        case (.boolean, .boolean): return
        case (.text(let options), .text(let text)) where options.contains(text): return
        default: throw ProjectError.invalidValue("Effect parameter \(id) has an invalid type or value.")
        }
    }
}

public struct ProjectEffectParameterDescriptor: Equatable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var defaultValue: ProjectEffectParameterValue
    public var domain: ProjectEffectParameterDomain
    public var help: String

    public init(id: String, displayName: String, defaultValue: ProjectEffectParameterValue, domain: ProjectEffectParameterDomain, help: String = "") {
        self.id = id
        self.displayName = displayName
        self.defaultValue = defaultValue
        self.domain = domain
        self.help = help
    }

    public var animatableKind: ProjectAnimatableValueKind? { domain.animatableKind }

    public func validatedDefault() throws -> Self {
        guard !id.isEmpty, !displayName.isEmpty else { throw ProjectError.invalidValue("Effect parameter descriptors require IDs and display names.") }
        _ = try defaultValue.validated()
        try domain.validate(defaultValue, id: id)
        return self
    }
}

public struct ProjectEffectDescriptor: Equatable, Sendable, Identifiable {
    public var id: ProjectEffectType { type }
    public var type: ProjectEffectType
    public var effectVersion: Int
    public var displayName: String
    public var category: ProjectEffectCategory
    public var executionMode: ProjectEffectExecutionMode
    public var keywords: [String]
    public var summary: String
    public var parameters: [ProjectEffectParameterDescriptor]

    public init(type: ProjectEffectType, effectVersion: Int = 1, displayName: String, category: ProjectEffectCategory, executionMode: ProjectEffectExecutionMode, keywords: [String], summary: String, parameters: [ProjectEffectParameterDescriptor]) {
        self.type = type
        self.effectVersion = effectVersion
        self.displayName = displayName
        self.category = category
        self.executionMode = executionMode
        self.keywords = keywords
        self.summary = summary
        self.parameters = parameters
    }

    public func parameter(id: String) -> ProjectEffectParameterDescriptor? { parameters.first { $0.id == id } }
    public var defaultParameters: [ProjectEffectParameter] { parameters.map { ProjectEffectParameter(id: $0.id, value: $0.defaultValue) } }

    public func validated() throws -> Self {
        guard effectVersion > 0, !displayName.isEmpty, !summary.isEmpty else { throw ProjectError.invalidValue("Effect descriptors require a positive version and user-facing metadata.") }
        guard Set(parameters.map(\.id)).count == parameters.count else { throw ProjectError.duplicateIdentity("effect parameter descriptor") }
        for parameter in parameters { _ = try parameter.validatedDefault() }
        return self
    }

    public func validate(parameters values: [ProjectEffectParameter]) throws {
        guard Set(values.map(\.id)).count == values.count else { throw ProjectError.duplicateIdentity("effect parameter") }
        let actual = Set(values.map(\.id))
        let expected = Set(parameters.map(\.id))
        guard actual == expected else {
            throw ProjectError.invalidValue("Effect parameters do not match descriptor. Unknown: \(actual.subtracting(expected).sorted()). Missing: \(expected.subtracting(actual).sorted()).")
        }
        for value in values {
            guard let descriptor = parameter(id: value.id) else { throw ProjectError.invalidValue("Unknown effect parameter: \(value.id).") }
            _ = try value.value.validated()
            try descriptor.domain.validate(value.value, id: value.id)
        }
    }
}

public enum ProjectEffectDescriptorRegistry {
    public static let all: [ProjectEffectDescriptor] = [
        .init(type: .gaussianBlur, displayName: "Gaussian Blur", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["blur", "gaussian", "soften"], summary: "True Gaussian blur processed through Core Image in the shared preview/export effect path.", parameters: [.init(id: GaussianBlurParameterID.radius, displayName: "Radius", defaultValue: .scalar(10), domain: .scalar(0...200))]),
        .init(type: .fastBoxBlur, displayName: "Fast Box Blur", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["blur", "box", "fast"], summary: "Fast box-kernel blur for responsive interactive softening.", parameters: [.init(id: FastBoxBlurParameterID.radius, displayName: "Radius", defaultValue: .scalar(10), domain: .scalar(0...200))]),
        .init(type: .directionalBlur, displayName: "Directional Blur", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["directional", "motion", "blur", "angle"], summary: "Directional motion-style blur with independent radius and angle.", parameters: [.init(id: DirectionalBlurParameterID.radius, displayName: "Radius", defaultValue: .scalar(12), domain: .scalar(0...200)), .init(id: DirectionalBlurParameterID.angle, displayName: "Angle", defaultValue: .scalar(0), domain: .scalar(-180...180))]),
        .init(type: .sharpen, displayName: "Sharpen", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["sharpen", "sharpness", "detail"], summary: "Luminance sharpening with keyframable sharpness.", parameters: [.init(id: SharpenParameterID.sharpness, displayName: "Sharpness", defaultValue: .scalar(0.4), domain: .scalar(0...2))]),
        .init(type: .median, displayName: "Median", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["median", "speckle", "noise", "smooth"], summary: "Median neighborhood filtering for small speckle and isolated-noise cleanup.", parameters: []),
        .init(type: .noiseReduction, displayName: "Noise Reduction", category: .blurAndSharpen, executionMode: .nativePixel, keywords: ["noise", "denoise", "grain", "cleanup"], summary: "Real-time Core Image noise reduction with detail recovery.", parameters: [.init(id: NoiseReductionParameterID.noiseLevel, displayName: "Noise Level", defaultValue: .scalar(0.02), domain: .scalar(0...0.1)), .init(id: NoiseReductionParameterID.sharpness, displayName: "Sharpness", defaultValue: .scalar(0.4), domain: .scalar(0...2))]),
        .init(type: .exposure, displayName: "Exposure", category: .colorCorrection, executionMode: .nativePixel, keywords: ["exposure", "ev", "stops", "light"], summary: "Exposure adjustment in photographic stops.", parameters: [.init(id: ExposureEffectParameterID.stops, displayName: "Stops", defaultValue: .scalar(0), domain: .scalar(-10...10))]),
        .init(type: .colorControls, displayName: "Color Controls", category: .colorCorrection, executionMode: .nativePixel, keywords: ["brightness", "contrast", "saturation", "color"], summary: "Brightness, contrast, and saturation controls in one stackable effect.", parameters: [.init(id: ColorControlsParameterID.brightness, displayName: "Brightness", defaultValue: .scalar(0), domain: .scalar(-1...1)), .init(id: ColorControlsParameterID.contrast, displayName: "Contrast", defaultValue: .scalar(1), domain: .scalar(0...4)), .init(id: ColorControlsParameterID.saturation, displayName: "Saturation", defaultValue: .scalar(1), domain: .scalar(0...2))]),
        .init(type: .hueAdjust, displayName: "Hue Adjust", category: .colorCorrection, executionMode: .nativePixel, keywords: ["hue", "color", "rotate", "angle"], summary: "Rotate hue by a keyframable angle.", parameters: [.init(id: HueAdjustParameterID.degrees, displayName: "Degrees", defaultValue: .scalar(0), domain: .scalar(-180...180))]),
        .init(type: .vibrance, displayName: "Vibrance", category: .colorCorrection, executionMode: .nativePixel, keywords: ["vibrance", "saturation", "color"], summary: "Selective saturation enhancement that protects already-saturated colors.", parameters: [.init(id: VibranceParameterID.amount, displayName: "Amount", defaultValue: .scalar(0), domain: .scalar(-1...1))]),
        .init(type: .gammaAdjust, displayName: "Gamma", category: .colorCorrection, executionMode: .nativePixel, keywords: ["gamma", "midtone", "tone"], summary: "Fast gamma-power tone adjustment for midtone shaping.", parameters: [.init(id: GammaAdjustParameterID.power, displayName: "Power", defaultValue: .scalar(1), domain: .scalar(0.1...3))]),
        .init(type: .highlightShadow, displayName: "Shadow/Highlight", category: .colorCorrection, executionMode: .nativePixel, keywords: ["shadow", "highlight", "dynamic range", "tone"], summary: "Independent shadow lift and highlight recovery on the live native path.", parameters: [.init(id: HighlightShadowParameterID.highlights, displayName: "Highlights", defaultValue: .scalar(1), domain: .scalar(0...1)), .init(id: HighlightShadowParameterID.shadows, displayName: "Shadows", defaultValue: .scalar(0), domain: .scalar(-1...1))]),
        .init(type: .sepiaTone, displayName: "Sepia Tone", category: .colorCorrection, executionMode: .nativePixel, keywords: ["sepia", "warm", "vintage", "tone"], summary: "Adjustable sepia toning for warm vintage looks.", parameters: [.init(id: SepiaToneParameterID.intensity, displayName: "Intensity", defaultValue: .scalar(1), domain: .scalar(0...1))]),
        .init(type: .invert, displayName: "Invert", category: .channel, executionMode: .nativePixel, keywords: ["invert", "negative", "channel"], summary: "Invert image channels using the native pixel processor.", parameters: []),
        .init(type: .posterize, displayName: "Posterize", category: .stylize, executionMode: .nativePixel, keywords: ["posterize", "levels", "quantize", "stylize"], summary: "Quantize color channels to a controllable number of tonal levels.", parameters: [.init(id: PosterizeParameterID.levels, displayName: "Levels", defaultValue: .scalar(6), domain: .scalar(2...30))]),
        .init(type: .mosaic, displayName: "Mosaic", category: .stylize, executionMode: .nativePixel, keywords: ["mosaic", "pixelate", "pixels", "block"], summary: "GPU-backed pixel mosaic with animated block scale.", parameters: [.init(id: MosaicParameterID.scale, displayName: "Scale", defaultValue: .scalar(16), domain: .scalar(1...200))]),
        .init(type: .findEdges, displayName: "Find Edges", category: .stylize, executionMode: .nativePixel, keywords: ["edge", "outline", "detect", "line"], summary: "Edge extraction for outlines, mattes, and stylized line treatments.", parameters: [.init(id: FindEdgesParameterID.intensity, displayName: "Intensity", defaultValue: .scalar(1), domain: .scalar(0...10))]),
        .init(type: .glow, displayName: "Glow", category: .stylize, executionMode: .nativePixel, keywords: ["glow", "bloom", "light", "neon"], summary: "Fast live bloom/glow for highlights and emissive graphics.", parameters: [.init(id: GlowParameterID.radius, displayName: "Radius", defaultValue: .scalar(10), domain: .scalar(0...100)), .init(id: GlowParameterID.intensity, displayName: "Intensity", defaultValue: .scalar(0.5), domain: .scalar(0...2))]),
        .init(type: .vignette, displayName: "Vignette", category: .stylize, executionMode: .nativePixel, keywords: ["vignette", "edge", "darken", "lens"], summary: "Fast adjustable edge vignette for finishing and focus control.", parameters: [.init(id: VignetteParameterID.radius, displayName: "Radius", defaultValue: .scalar(1), domain: .scalar(0...2)), .init(id: VignetteParameterID.intensity, displayName: "Intensity", defaultValue: .scalar(0), domain: .scalar(0...2))]),
        .init(type: .cartoon, displayName: "Cartoon", category: .stylize, executionMode: .nativePixel, keywords: ["cartoon", "comic", "toon", "stylize"], summary: "GPU-backed comic/cartoon stylization for fast graphic looks.", parameters: []),
        .init(type: .twirl, displayName: "Twirl", category: .distort, executionMode: .nativePixel, keywords: ["twirl", "swirl", "warp", "distort"], summary: "Center-based twirl distortion with animated radius and angle.", parameters: [.init(id: TwirlParameterID.radius, displayName: "Radius", defaultValue: .scalar(300), domain: .scalar(0...2000)), .init(id: TwirlParameterID.angle, displayName: "Angle", defaultValue: .scalar(0), domain: .scalar(-360...360))]),
        .init(type: .depthMap, displayName: "Depth Map", category: .ai, executionMode: .aiBake, keywords: ["depth", "depth anything", "z", "3d channel"], summary: "Generate an editable depth representation from the selected media layer.", parameters: [.init(id: DepthMapParameterID.model, displayName: "Model", defaultValue: .text("depth-anything-v2-small-f16"), domain: .text(options: ["depth-anything-v2-small-f16"])), .init(id: DepthMapParameterID.quality, displayName: "Quality", defaultValue: .text("balanced"), domain: .text(options: ["preview", "balanced", "quality"])), .init(id: DepthMapParameterID.invert, displayName: "Invert", defaultValue: .boolean(false), domain: .boolean), .init(id: DepthMapParameterID.near, displayName: "Near", defaultValue: .scalar(0), domain: .scalar(0...1)), .init(id: DepthMapParameterID.far, displayName: "Far", defaultValue: .scalar(1), domain: .scalar(0...1)), .init(id: DepthMapParameterID.smoothing, displayName: "Smoothing", defaultValue: .scalar(0.08), domain: .scalar(0...1)), .init(id: DepthMapParameterID.edgeRefinement, displayName: "Edge Refinement", defaultValue: .scalar(0.18), domain: .scalar(0...1)), .init(id: DepthMapParameterID.temporalSmoothing, displayName: "Temporal Smooth", defaultValue: .scalar(0.12), domain: .scalar(0...1)), .init(id: DepthMapParameterID.output, displayName: "Output", defaultValue: .text("depth"), domain: .text(options: ["depth", "alpha"]))]),
        .init(type: .cutout, displayName: "Cutout", category: .ai, executionMode: .aiBake, keywords: ["cutout", "mask", "foreground", "person", "remove background"], summary: "Create a foreground alpha matte with on-device segmentation.", parameters: [.init(id: CutoutParameterID.quality, displayName: "Quality", defaultValue: .text("balanced"), domain: .text(options: ["preview", "balanced", "quality"])), .init(id: CutoutParameterID.mode, displayName: "Mode", defaultValue: .text("foregroundFast"), domain: .text(options: ["personFast", "foregroundFast", "promptQuality"])), .init(id: CutoutParameterID.feather, displayName: "Feather", defaultValue: .scalar(0.04), domain: .scalar(0...1)), .init(id: CutoutParameterID.edgeCleanup, displayName: "Edge Cleanup", defaultValue: .scalar(0.2), domain: .scalar(0...1)), .init(id: CutoutParameterID.temporalSmoothing, displayName: "Temporal Smooth", defaultValue: .scalar(0.15), domain: .scalar(0...1)), .init(id: CutoutParameterID.promptX, displayName: "Prompt X", defaultValue: .scalar(0.5), domain: .scalar(0...1)), .init(id: CutoutParameterID.promptY, displayName: "Prompt Y", defaultValue: .scalar(0.5), domain: .scalar(0...1))]),
        .init(type: .upscale, displayName: "Upscale", category: .ai, executionMode: .aiBake, keywords: ["upscale", "super resolution", "resolution", "4x"], summary: "Increase source detail and resolution with the bundled RealESRGAN model.", parameters: [.init(id: UpscaleParameterID.quality, displayName: "Quality", defaultValue: .text("balanced"), domain: .text(options: ["preview", "balanced", "quality"])), .init(id: UpscaleParameterID.profile, displayName: "Profile", defaultValue: .text("general"), domain: .text(options: ["general", "animeGame"])), .init(id: UpscaleParameterID.scale, displayName: "Scale", defaultValue: .scalar(2), domain: .scalar(1...4)), .init(id: UpscaleParameterID.tileOverlap, displayName: "Tile Overlap", defaultValue: .integer(32), domain: .integer(0...256))]),
        .init(type: .restore, displayName: "Restore", category: .ai, executionMode: .aiBake, keywords: ["restore", "denoise", "deblur", "artifact", "detail"], summary: "Denoise and restore compressed or degraded footage.", parameters: [.init(id: RestorationParameterID.quality, displayName: "Quality", defaultValue: .text("balanced"), domain: .text(options: ["preview", "balanced", "quality"])), .init(id: RestorationParameterID.denoise, displayName: "Denoise", defaultValue: .scalar(0.45), domain: .scalar(0...1)), .init(id: RestorationParameterID.deblur, displayName: "Deblur", defaultValue: .scalar(0), domain: .scalar(0...1)), .init(id: RestorationParameterID.artifactRemoval, displayName: "Artifact Removal", defaultValue: .scalar(0.25), domain: .scalar(0...1)), .init(id: RestorationParameterID.detailRecovery, displayName: "Detail Recovery", defaultValue: .scalar(0.25), domain: .scalar(0...1)), .init(id: RestorationParameterID.faceRestoration, displayName: "Face Restoration", defaultValue: .boolean(false), domain: .boolean)])
    ] + ProjectEffectExpansionDescriptors.all + ProjectEffectV17Descriptors.all

    private static let byType: [ProjectEffectType: ProjectEffectDescriptor] = Dictionary(uniqueKeysWithValues: all.map { ($0.type, $0) })

    public static func descriptor(for type: ProjectEffectType) -> ProjectEffectDescriptor {
        guard let descriptor = byType[type] else { preconditionFailure("Missing effect descriptor for \(type.rawValue)") }
        return descriptor
    }
}

public extension ProjectEffectType {
    var descriptor: ProjectEffectDescriptor { ProjectEffectDescriptorRegistry.descriptor(for: self) }
    var displayName: String { descriptor.displayName }
    var category: ProjectEffectCategory { descriptor.category }
    var executionMode: ProjectEffectExecutionMode { descriptor.executionMode }
}

public struct ProjectEffectPreset: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var name: String
    public var effectType: ProjectEffectType
    public var effectVersion: Int
    public var parameters: [ProjectEffectParameter]

    public init(schemaVersion: Int = ProjectEffectPreset.currentSchemaVersion, name: String, effectType: ProjectEffectType, effectVersion: Int, parameters: [ProjectEffectParameter]) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.effectType = effectType
        self.effectVersion = effectVersion
        self.parameters = parameters
    }

    public static func capture(name: String, effect: ProjectEffect) throws -> Self {
        _ = try effect.validated()
        return try Self(name: name, effectType: effect.type, effectVersion: effect.version, parameters: effect.parameters).validated()
    }

    public func validated() throws -> Self {
        guard schemaVersion == Self.currentSchemaVersion else { throw ProjectError.invalidValue("Unsupported effect preset schema version: \(schemaVersion).") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.invalidValue("Effect preset names must not be empty.") }
        _ = try ProjectEffect(type: effectType, version: effectVersion, parameters: parameters).validated()
        return self
    }

    public func instantiate(id: VertexID = VertexID(), enabled: Bool = true) throws -> ProjectEffect {
        _ = try validated()
        return try ProjectEffect(id: id, type: effectType, version: effectVersion, enabled: enabled, parameters: parameters).validated()
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, name, effectType, effectVersion, parameters, type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let declaredSchema = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let name = try container.decode(String.self, forKey: .name)
        switch declaredSchema {
        case 1:
            let migratedType = try container.decodeIfPresent(ProjectEffectType.self, forKey: .effectType) ?? container.decode(ProjectEffectType.self, forKey: .type)
            self.schemaVersion = Self.currentSchemaVersion
            self.name = name
            self.effectType = migratedType
            self.effectVersion = try container.decodeIfPresent(Int.self, forKey: .effectVersion) ?? ProjectEffectDescriptorRegistry.descriptor(for: migratedType).effectVersion
            self.parameters = try container.decode([ProjectEffectParameter].self, forKey: .parameters)
        case Self.currentSchemaVersion:
            self.schemaVersion = Self.currentSchemaVersion
            self.name = name
            self.effectType = try container.decode(ProjectEffectType.self, forKey: .effectType)
            self.effectVersion = try container.decode(Int.self, forKey: .effectVersion)
            self.parameters = try container.decode([ProjectEffectParameter].self, forKey: .parameters)
        default:
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported effect preset schema version: \(declaredSchema).")
        }
        _ = try validated()
    }

    public func encode(to encoder: Encoder) throws {
        _ = try validated()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(name, forKey: .name)
        try container.encode(effectType, forKey: .effectType)
        try container.encode(effectVersion, forKey: .effectVersion)
        try container.encode(parameters, forKey: .parameters)
    }
}

public enum ProjectEffectPresetCodec {
    public static func encode(_ preset: ProjectEffectPreset) throws -> Data {
        let validated = try preset.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(validated)
    }

    public static func decode(_ data: Data) throws -> ProjectEffectPreset { try JSONDecoder().decode(ProjectEffectPreset.self, from: data).validated() }
}
