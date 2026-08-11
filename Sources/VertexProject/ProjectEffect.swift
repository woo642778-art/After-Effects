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
        let descriptor = ProjectEffectDescriptorRegistry.descriptor(for: type)
        return Self(
            type: type,
            version: descriptor.effectVersion,
            parameters: descriptor.defaultParameters
        )
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
        guard Set(map(\.id)).count == count else {
            throw ProjectError.duplicateIdentity("effect")
        }
        for effect in self { _ = try effect.validated() }
        return self
    }
}
