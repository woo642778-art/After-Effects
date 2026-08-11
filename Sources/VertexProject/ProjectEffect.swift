import Foundation
import VertexCore

public enum ProjectEffectType: String, Codable, CaseIterable, Sendable {
    case depthMap
    case cutout
    case upscale
    case restore
    case gaussianBlur
    case fastBoxBlur
    case directionalBlur
    case sharpen
    case median
    case noiseReduction
    case exposure
    case colorControls
    case hueAdjust
    case vibrance
    case gammaAdjust
    case highlightShadow
    case sepiaTone
    case invert
    case posterize
    case mosaic
    case findEdges
    case glow
    case vignette
    case cartoon
    case twirl

    // Blur & Sharpen expansion
    case discBlur
    case zoomBlur
    case bokehBlur
    case unsharpMask
    case morphologyGradient
    case morphologyMinimum
    case morphologyMaximum
    case morphologyRectangleMinimum
    case morphologyRectangleMaximum

    // Color / Channel expansion
    case temperatureTint
    case colorMonochrome
    case colorClamp
    case photoChrome
    case photoFade
    case photoInstant
    case photoMono
    case photoNoir
    case photoProcess
    case photoTonal
    case photoTransfer
    case linearToSRGB
    case sRGBToLinear
    case colorThreshold
    case colorThresholdOtsu

    // Stylize / Halftone expansion
    case crystallize
    case edgeWork
    case gloom
    case hexagonalPixelate
    case lineOverlay
    case pointillize
    case circularScreen
    case dotScreen
    case hatchedScreen
    case lineScreen
    case cmykHalftone
    case depthOfField

    // Distortion expansion
    case bumpDistortion
    case bumpLinear
    case circleSplash
    case circularWrap
    case droste
    case holeDistortion
    case lightTunnel
    case pinchDistortion
    case stretchCrop
    case torusLens
    case vortexDistortion
    case glassLozenge

    // Tile expansion
    case kaleidoscope
    case opTile
    case triangleKaleidoscope
    case sixfoldReflectedTile
    case twelvefoldReflectedTile
    case parallelogramTile
    case triangleTile
    case fourfoldReflectedTile
    case fourfoldRotatedTile
    case fourfoldTranslatedTile
    case eightfoldReflectedTile
    case glideReflectedTile
    case sixfoldRotatedTile

    // Vertex2 clean-room composites
    case vertexAuraGlow
    case vertexDarkGlow
    case vertexEdgeGlow
    case vertexHalation
    case vertexFilmGrain
    case vertexScanlines
    case vertexRGBSplit
    case vertexPrismBlur
    case vertexLightLeak
    case vertexSunRays

    // Keying / matte expansion
    case lumaKey
    case brightMatte
    case darkMatte

    // V17 standard and clean-room effects
    case motionBlur
    case pixelate
    case sharpenLuminance
    case maximumComponent
    case minimumComponent
    case whitePointAdjust
    case falseColor
    case colorMatrix
    case maskToAlpha
    case edges
    case affineTile
    case checkerboard
    case stripes
    case starShine
    case vertexGlare
    case vertexLightStreaks
    case vertexAnalogDamage

    // V17 particles and procedural graphics
    case vertexParticleField
    case vertexSparks
    case vertexSnow
    case vertexDust
    case vertexStarfield
    case vertexTrailParticles
    case vertexFractalNoise
    case vertexTurbulenceTexture
    case vertexPlasma
    case vertexCellularTexture
    case vertexGrid
    case vertexRings

    public var isNativePixelEffect: Bool {
        switch self {
        case .depthMap, .cutout, .upscale, .restore:
            false
        default:
            true
        }
    }
}

public enum ProjectEffectParameterValue: Codable, Equatable, Sendable {
    case scalar(Double)
    case integer(Int)
    case boolean(Bool)
    case text(String)

    public var animatableKind: ProjectAnimatableValueKind? {
        switch self {
        case .scalar: .scalar
        case .boolean: .boolean
        case .integer, .text: nil
        }
    }

    public func validated() throws -> Self {
        if case .scalar(let value) = self, !value.isFinite {
            throw ProjectError.invalidValue("Effect scalar parameters must be finite.")
        }
        return self
    }
}

public struct ProjectEffectParameter: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var value: ProjectEffectParameterValue

    public init(id: String, value: ProjectEffectParameterValue) {
        self.id = id
        self.value = value
    }
}

public enum DepthMapParameterID {
    public static let model = "model"
    public static let quality = "quality"
    public static let invert = "invert"
    public static let near = "near"
    public static let far = "far"
    public static let smoothing = "smoothing"
    public static let edgeRefinement = "edgeRefinement"
    public static let temporalSmoothing = "temporalSmoothing"
    public static let output = "output"
}

public enum CutoutParameterID {
    public static let quality = "quality"
    public static let mode = "mode"
    public static let feather = "feather"
    public static let edgeCleanup = "edgeCleanup"
    public static let temporalSmoothing = "temporalSmoothing"
    public static let promptX = "promptX"
    public static let promptY = "promptY"
}

public enum UpscaleParameterID {
    public static let quality = "quality"
    public static let profile = "profile"
    public static let scale = "scale"
    public static let tileOverlap = "tileOverlap"
}

public enum RestorationParameterID {
    public static let quality = "quality"
    public static let denoise = "denoise"
    public static let deblur = "deblur"
    public static let artifactRemoval = "artifactRemoval"
    public static let detailRecovery = "detailRecovery"
    public static let faceRestoration = "faceRestoration"
}

public enum GaussianBlurParameterID { public static let radius = "radius" }
public enum FastBoxBlurParameterID { public static let radius = "radius" }
public enum DirectionalBlurParameterID {
    public static let radius = "radius"
    public static let angle = "angle"
}
public enum SharpenParameterID { public static let sharpness = "sharpness" }
public enum NoiseReductionParameterID {
    public static let noiseLevel = "noiseLevel"
    public static let sharpness = "sharpness"
}
public enum ExposureEffectParameterID { public static let stops = "stops" }
public enum ColorControlsParameterID {
    public static let brightness = "brightness"
    public static let contrast = "contrast"
    public static let saturation = "saturation"
}
public enum HueAdjustParameterID { public static let degrees = "degrees" }
public enum VibranceParameterID { public static let amount = "amount" }
public enum GammaAdjustParameterID { public static let power = "power" }
public enum HighlightShadowParameterID {
    public static let highlights = "highlights"
    public static let shadows = "shadows"
}
public enum SepiaToneParameterID { public static let intensity = "intensity" }
public enum PosterizeParameterID { public static let levels = "levels" }
public enum MosaicParameterID { public static let scale = "scale" }
public enum FindEdgesParameterID { public static let intensity = "intensity" }
public enum GlowParameterID {
    public static let radius = "radius"
    public static let intensity = "intensity"
}
public enum VignetteParameterID {
    public static let radius = "radius"
    public static let intensity = "intensity"
}
public enum TwirlParameterID {
    public static let radius = "radius"
    public static let angle = "angle"
}

public struct ProjectEffect: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var type: ProjectEffectType
    public var version: Int
    public var enabled: Bool
    public var parameters: [ProjectEffectParameter]

    public init(
        id: VertexID = VertexID(),
        type: ProjectEffectType,
        version: Int = 1,
        enabled: Bool = true,
        parameters: [ProjectEffectParameter]
    ) {
        self.id = id
        self.type = type
        self.version = version
        self.enabled = enabled
        self.parameters = parameters
    }

    public static func makeDefault(_ type: ProjectEffectType) -> Self {
        let descriptor = ProjectEffectDescriptorRegistry.descriptor(for: type)
        return Self(type: type, version: descriptor.effectVersion, parameters: descriptor.defaultParameters)
    }

    public func parameter(id: String) -> ProjectEffectParameter? {
        parameters.first { $0.id == id }
    }

    public mutating func setParameter(id: String, value: ProjectEffectParameterValue) throws {
        guard let index = parameters.firstIndex(where: { $0.id == id }) else {
            throw ProjectError.invalidValue("Effect parameter is missing: \(id).")
        }
        parameters[index].value = value
        _ = try validated()
    }

    public func validated() throws -> Self {
        let descriptor = ProjectEffectDescriptorRegistry.descriptor(for: type)
        guard version == descriptor.effectVersion else {
            throw ProjectError.invalidValue("Unsupported project effect version: \(version) for \(type.rawValue).")
        }
        guard Set(parameters.map(\.id)).count == parameters.count else {
            throw ProjectError.duplicateIdentity("effect parameter")
        }
        for parameter in parameters {
            guard !parameter.id.isEmpty else {
                throw ProjectError.invalidValue("Effect parameter IDs must not be empty.")
            }
        }
        try descriptor.validate(parameters: parameters)
        try validateCrossParameterRules()
        return self
    }

    private func validateCrossParameterRules() throws {
        if type == .depthMap,
           case .scalar(let near)? = parameter(id: DepthMapParameterID.near)?.value,
           case .scalar(let far)? = parameter(id: DepthMapParameterID.far)?.value,
           !(near < far) {
            throw ProjectError.invalidValue("Depth near must be less than far.")
        }
    }
}

public extension Array where Element == ProjectEffect {
    func validatedEffects() throws -> [ProjectEffect] {
        guard Set(map(\.id)).count == count else { throw ProjectError.duplicateIdentity("effect") }
        for effect in self { _ = try effect.validated() }
        return self
    }
}
