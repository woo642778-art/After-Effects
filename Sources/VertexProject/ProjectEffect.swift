import Foundation
import VertexCore

public enum ProjectEffectType: String, Codable, CaseIterable, Sendable {
    case depthMap
    case cutout
    case upscale
    case restore
    case gaussianBlur
    case sharpen
    case exposure
    case colorControls
    case hueAdjust
    case invert

    public var isNativePixelEffect: Bool {
        switch self {
        case .gaussianBlur, .sharpen, .exposure, .colorControls, .hueAdjust, .invert: true
        case .depthMap, .cutout, .upscale, .restore: false
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

public enum GaussianBlurParameterID {
    public static let radius = "radius"
}

public enum SharpenParameterID {
    public static let sharpness = "sharpness"
}

public enum ExposureEffectParameterID {
    public static let stops = "stops"
}

public enum ColorControlsParameterID {
    public static let brightness = "brightness"
    public static let contrast = "contrast"
    public static let saturation = "saturation"
}

public enum HueAdjustParameterID {
    public static let degrees = "degrees"
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
        switch type {
        case .depthMap:
            return Self(type: type, parameters: [
                .init(id: DepthMapParameterID.model, value: .text("depth-anything-v2-small-f16")),
                .init(id: DepthMapParameterID.quality, value: .text("balanced")),
                .init(id: DepthMapParameterID.invert, value: .boolean(false)),
                .init(id: DepthMapParameterID.near, value: .scalar(0)),
                .init(id: DepthMapParameterID.far, value: .scalar(1)),
                .init(id: DepthMapParameterID.smoothing, value: .scalar(0.08)),
                .init(id: DepthMapParameterID.edgeRefinement, value: .scalar(0.18)),
                .init(id: DepthMapParameterID.temporalSmoothing, value: .scalar(0.12)),
                .init(id: DepthMapParameterID.output, value: .text("depth"))
            ])
        case .cutout:
            return Self(type: type, parameters: [
                .init(id: CutoutParameterID.quality, value: .text("balanced")),
                .init(id: CutoutParameterID.mode, value: .text("foregroundFast")),
                .init(id: CutoutParameterID.feather, value: .scalar(0.04)),
                .init(id: CutoutParameterID.edgeCleanup, value: .scalar(0.2)),
                .init(id: CutoutParameterID.temporalSmoothing, value: .scalar(0.15)),
                .init(id: CutoutParameterID.promptX, value: .scalar(0.5)),
                .init(id: CutoutParameterID.promptY, value: .scalar(0.5))
            ])
        case .upscale:
            return Self(type: type, parameters: [
                .init(id: UpscaleParameterID.quality, value: .text("balanced")),
                .init(id: UpscaleParameterID.profile, value: .text("general")),
                .init(id: UpscaleParameterID.scale, value: .scalar(2)),
                .init(id: UpscaleParameterID.tileOverlap, value: .integer(32))
            ])
        case .restore:
            return Self(type: type, parameters: [
                .init(id: RestorationParameterID.quality, value: .text("balanced")),
                .init(id: RestorationParameterID.denoise, value: .scalar(0.45)),
                .init(id: RestorationParameterID.deblur, value: .scalar(0)),
                .init(id: RestorationParameterID.artifactRemoval, value: .scalar(0.25)),
                .init(id: RestorationParameterID.detailRecovery, value: .scalar(0.25)),
                .init(id: RestorationParameterID.faceRestoration, value: .boolean(false))
            ])
        case .gaussianBlur:
            return Self(type: type, parameters: [
                .init(id: GaussianBlurParameterID.radius, value: .scalar(10))
            ])
        case .sharpen:
            return Self(type: type, parameters: [
                .init(id: SharpenParameterID.sharpness, value: .scalar(0.4))
            ])
        case .exposure:
            return Self(type: type, parameters: [
                .init(id: ExposureEffectParameterID.stops, value: .scalar(0))
            ])
        case .colorControls:
            return Self(type: type, parameters: [
                .init(id: ColorControlsParameterID.brightness, value: .scalar(0)),
                .init(id: ColorControlsParameterID.contrast, value: .scalar(1)),
                .init(id: ColorControlsParameterID.saturation, value: .scalar(1))
            ])
        case .hueAdjust:
            return Self(type: type, parameters: [
                .init(id: HueAdjustParameterID.degrees, value: .scalar(0))
            ])
        case .invert:
            return Self(type: type, parameters: [])
        }
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
        guard version == 1 else { throw ProjectError.invalidValue("Unsupported project effect version: \(version).") }
        guard Set(parameters.map(\.id)).count == parameters.count else {
            throw ProjectError.duplicateIdentity("effect parameter")
        }
        for parameter in parameters {
            guard !parameter.id.isEmpty else { throw ProjectError.invalidValue("Effect parameter IDs must not be empty.") }
            _ = try parameter.value.validated()
        }
        try validateDescriptor()
        return self
    }

    private func validateDescriptor() throws {
        let expected: [String: ParameterRule]
        switch type {
        case .depthMap:
            expected = [
                DepthMapParameterID.model: .text(allowed: ["depth-anything-v2-small-f16"]),
                DepthMapParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                DepthMapParameterID.invert: .boolean,
                DepthMapParameterID.near: .scalar(0...1),
                DepthMapParameterID.far: .scalar(0...1),
                DepthMapParameterID.smoothing: .scalar(0...1),
                DepthMapParameterID.edgeRefinement: .scalar(0...1),
                DepthMapParameterID.temporalSmoothing: .scalar(0...1),
                DepthMapParameterID.output: .text(allowed: ["depth", "alpha"])
            ]
        case .cutout:
            expected = [
                CutoutParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                CutoutParameterID.mode: .text(allowed: ["personFast", "foregroundFast", "promptQuality"]),
                CutoutParameterID.feather: .scalar(0...1),
                CutoutParameterID.edgeCleanup: .scalar(0...1),
                CutoutParameterID.temporalSmoothing: .scalar(0...1),
                CutoutParameterID.promptX: .scalar(0...1),
                CutoutParameterID.promptY: .scalar(0...1)
            ]
        case .upscale:
            expected = [
                UpscaleParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                UpscaleParameterID.profile: .text(allowed: ["general", "animeGame"]),
                UpscaleParameterID.scale: .scalar(1...4),
                UpscaleParameterID.tileOverlap: .integer(0...256)
            ]
        case .restore:
            expected = [
                RestorationParameterID.quality: .text(allowed: ["preview", "balanced", "quality"]),
                RestorationParameterID.denoise: .scalar(0...1),
                RestorationParameterID.deblur: .scalar(0...1),
                RestorationParameterID.artifactRemoval: .scalar(0...1),
                RestorationParameterID.detailRecovery: .scalar(0...1),
                RestorationParameterID.faceRestoration: .boolean
            ]
        case .gaussianBlur:
            expected = [GaussianBlurParameterID.radius: .scalar(0...200)]
        case .sharpen:
            expected = [SharpenParameterID.sharpness: .scalar(0...2)]
        case .exposure:
            expected = [ExposureEffectParameterID.stops: .scalar(-10...10)]
        case .colorControls:
            expected = [
                ColorControlsParameterID.brightness: .scalar(-1...1),
                ColorControlsParameterID.contrast: .scalar(0...4),
                ColorControlsParameterID.saturation: .scalar(0...2)
            ]
        case .hueAdjust:
            expected = [HueAdjustParameterID.degrees: .scalar(-180...180)]
        case .invert:
            expected = [:]
        }
        guard Set(parameters.map(\.id)) == Set(expected.keys) else {
            let unknown = Set(parameters.map(\.id)).subtracting(expected.keys).sorted()
            let missing = Set(expected.keys).subtracting(parameters.map(\.id)).sorted()
            throw ProjectError.invalidValue("Effect parameters do not match descriptor. Unknown: \(unknown). Missing: \(missing).")
        }
        for parameter in parameters {
            guard let rule = expected[parameter.id] else { throw ProjectError.invalidValue("Unknown effect parameter: \(parameter.id).") }
            try rule.validate(parameter.value, id: parameter.id)
        }
        if type == .depthMap,
           case .scalar(let near)? = parameter(id: DepthMapParameterID.near)?.value,
           case .scalar(let far)? = parameter(id: DepthMapParameterID.far)?.value,
           !(near < far) {
            throw ProjectError.invalidValue("Depth near must be less than far.")
        }
    }
}

private enum ParameterRule {
    case scalar(ClosedRange<Double>)
    case integer(ClosedRange<Int>)
    case boolean
    case text(allowed: Set<String>)

    func validate(_ value: ProjectEffectParameterValue, id: String) throws {
        switch (self, value) {
        case (.scalar(let range), .scalar(let scalar)) where scalar.isFinite && range.contains(scalar): return
        case (.integer(let range), .integer(let integer)) where range.contains(integer): return
        case (.boolean, .boolean): return
        case (.text(let allowed), .text(let text)) where allowed.contains(text): return
        default: throw ProjectError.invalidValue("Effect parameter \(id) has an invalid type or value.")
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
