import Foundation
import VertexCore

public enum LayerBlendMode: String, Codable, CaseIterable, Sendable {
    case normal
    case add
    case multiply
    case screen
}

public enum AdjustmentScope: String, Codable, CaseIterable, Sendable {
    case belowAll
}

public enum CameraProjection: String, Codable, CaseIterable, Sendable {
    case perspective
}

public struct CameraLayerSettings: Codable, Equatable, Sendable {
    public var projection: CameraProjection
    public var focalLengthMillimeters: Double
    public var nearClip: Double
    public var farClip: Double
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double
    public var pointOfInterestX: Double
    public var pointOfInterestY: Double
    public var pointOfInterestZ: Double

    public init(
        projection: CameraProjection = .perspective,
        focalLengthMillimeters: Double = 50,
        nearClip: Double = 0.1,
        farClip: Double = 10_000,
        positionX: Double = 0,
        positionY: Double = 0,
        positionZ: Double = 1,
        pointOfInterestX: Double = 0,
        pointOfInterestY: Double = 0,
        pointOfInterestZ: Double = 0
    ) {
        self.projection = projection
        self.focalLengthMillimeters = focalLengthMillimeters
        self.nearClip = nearClip
        self.farClip = farClip
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.pointOfInterestX = pointOfInterestX
        self.pointOfInterestY = pointOfInterestY
        self.pointOfInterestZ = pointOfInterestZ
    }

    public static let `default` = CameraLayerSettings()

    public func validated() throws -> Self {
        let values = [focalLengthMillimeters, nearClip, farClip, positionX, positionY, positionZ, pointOfInterestX, pointOfInterestY, pointOfInterestZ]
        guard values.allSatisfy(\.isFinite), focalLengthMillimeters > 0, nearClip > 0, farClip > nearClip else {
            throw ProjectError.invalidValue("Camera values must be finite, focal length and near clip positive, and far clip greater than near clip.")
        }
        return self
    }
}

public enum LightKind: String, Codable, CaseIterable, Sendable {
    case point
    case directional
    case spot
}

public struct LightLayerSettings: Codable, Equatable, Sendable {
    public var kind: LightKind
    public var color: ProjectRGBAColor
    public var intensity: Double
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double
    public var directionX: Double
    public var directionY: Double
    public var directionZ: Double
    public var coneAngleDegrees: Double
    public var coneFeather: Double

    public init(
        kind: LightKind = .point,
        color: ProjectRGBAColor = .black,
        intensity: Double = 1,
        positionX: Double = 0,
        positionY: Double = 0,
        positionZ: Double = 1,
        directionX: Double = 0,
        directionY: Double = 0,
        directionZ: Double = -1,
        coneAngleDegrees: Double = 45,
        coneFeather: Double = 0
    ) {
        self.kind = kind
        self.color = color
        self.intensity = intensity
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.directionX = directionX
        self.directionY = directionY
        self.directionZ = directionZ
        self.coneAngleDegrees = coneAngleDegrees
        self.coneFeather = coneFeather
    }

    public static let `default` = LightLayerSettings()

    public func validated() throws -> Self {
        let values = [intensity, positionX, positionY, positionZ, directionX, directionY, directionZ, coneAngleDegrees, coneFeather]
        guard values.allSatisfy(\.isFinite), intensity >= 0, (0...180).contains(coneAngleDegrees), (0...1).contains(coneFeather) else {
            throw ProjectError.invalidValue("Light values are outside their supported finite ranges.")
        }
        _ = try color.validated()
        return self
    }
}

public struct LayerTiming: Codable, Equatable, Sendable {
    public var startTime: RationalTime
    public var inPoint: RationalTime
    public var outPoint: RationalTime

    public init(startTime: RationalTime, inPoint: RationalTime, outPoint: RationalTime) {
        self.startTime = startTime
        self.inPoint = inPoint
        self.outPoint = outPoint
    }

    public func validated(for composition: ProjectComposition) throws -> Self {
        guard inPoint >= .zero, inPoint < outPoint, outPoint <= composition.duration else {
            throw ProjectError.invalidValue("Layer timing must satisfy 0 <= In < Out <= composition duration.")
        }
        return self
    }
}

public struct LayerTransform: Codable, Equatable, Sendable {
    public var positionX: Double
    public var positionY: Double
    public var anchorX: Double
    public var anchorY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
    public var opacity: Double

    public init(positionX: Double, positionY: Double, anchorX: Double, anchorY: Double, scaleX: Double, scaleY: Double, rotationDegrees: Double, opacity: Double) {
        self.positionX = positionX
        self.positionY = positionY
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }

    public static let identity = LayerTransform(positionX: 0.5, positionY: 0.5, anchorX: 0.5, anchorY: 0.5, scaleX: 1, scaleY: 1, rotationDegrees: 0, opacity: 1)

    public func validated() throws -> Self {
        let values = [positionX, positionY, anchorX, anchorY, scaleX, scaleY, rotationDegrees, opacity]
        guard values.allSatisfy(\.isFinite), scaleX > 0, scaleY > 0, (0...1).contains(opacity) else {
            throw ProjectError.invalidValue("Layer transform values must be finite, scales positive, and opacity within 0...1.")
        }
        return self
    }
}

public enum LayerOperation: Codable, Equatable, Sendable {
    case exposure(stops: Double)
    case saturation(value: Double)
    case invert(enabled: Bool)

    public func validated() throws -> Self {
        switch self {
        case .exposure(let stops):
            guard stops.isFinite else { throw ProjectError.invalidValue("Layer exposure must be finite.") }
        case .saturation(let value):
            guard value.isFinite, value >= 0 else { throw ProjectError.invalidValue("Layer saturation must be finite and nonnegative.") }
        case .invert:
            break
        }
        return self
    }
}

public enum LayerSource: Codable, Equatable, Sendable {
    case media(mediaID: VertexID, sourceStartTime: RationalTime)
    case adjustment(scope: AdjustmentScope)
    case null
    case guide
    case camera(CameraLayerSettings)
    case light(LightLayerSettings)
    case composition(compositionID: VertexID, sourceStartTime: RationalTime)

    public var isModelOnly: Bool {
        switch self {
        case .null, .guide, .camera, .light: true
        default: false
        }
    }
}

public struct ProjectLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var compositionID: VertexID
    public var name: String
    public var source: LayerSource
    public var enabled: Bool
    public var locked: Bool
    public var solo: Bool
    public var timing: LayerTiming
    public var transform: LayerTransform
    public var blendMode: LayerBlendMode
    public var operations: [LayerOperation]

    public init(id: VertexID = VertexID(), compositionID: VertexID, name: String, source: LayerSource, enabled: Bool = true, locked: Bool = false, solo: Bool = false, timing: LayerTiming, transform: LayerTransform = .identity, blendMode: LayerBlendMode = .normal, operations: [LayerOperation] = []) {
        self.id = id
        self.compositionID = compositionID
        self.name = name
        self.source = source
        self.enabled = enabled
        self.locked = locked
        self.solo = solo
        self.timing = timing
        self.transform = transform
        self.blendMode = blendMode
        self.operations = operations
    }

    public func validated(in document: ProjectDocument) throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Layer name must not be empty.")
        }
        guard let composition = document.composition(id: compositionID) else {
            throw ProjectError.invalidValue("Layer owner composition is missing.")
        }
        _ = try timing.validated(for: composition)
        _ = try transform.validated()
        for operation in operations { _ = try operation.validated() }

        switch source {
        case .media(let mediaID, let sourceStartTime):
            guard sourceStartTime >= .zero else { throw ProjectError.invalidValue("Media source start time must be nonnegative.") }
            guard document.mediaRegistry.contains(where: { $0.id == mediaID }) else {
                throw ProjectError.invalidValue("Media layer references missing media: \(mediaID.rawValue).")
            }
        case .composition(let targetID, let sourceStartTime):
            guard sourceStartTime >= .zero else { throw ProjectError.invalidValue("Nested source start time must be nonnegative.") }
            guard document.composition(id: targetID) != nil else {
                throw ProjectError.invalidValue("Nested layer references a missing composition.")
            }
        case .adjustment:
            guard blendMode == .normal else { throw ProjectError.invalidValue("Adjustment layers use Normal blend mode in schema 2.") }
        case .null, .guide:
            guard blendMode == .normal, operations.isEmpty else { throw ProjectError.invalidValue("Model-only layers use Normal blend mode and no pixel operations.") }
        case .camera(let settings):
            _ = try settings.validated()
            guard blendMode == .normal, operations.isEmpty else { throw ProjectError.invalidValue("Camera layers use Normal blend mode and no pixel operations.") }
        case .light(let settings):
            _ = try settings.validated()
            guard blendMode == .normal, operations.isEmpty else { throw ProjectError.invalidValue("Light layers use Normal blend mode and no pixel operations.") }
        }
        return self
    }
}
