import Foundation
import VertexCore

public struct AIFrameEffectKey: Codable, Equatable, Hashable, Sendable {
    public let sourceFingerprint: String
    public let exactTime: RationalTime
    public let modelID: String
    public let modelDigest: String
    public let effectType: String
    public let algorithmVersion: Int
    public let parameterDigest: String
    public let qualityTier: String
    public let width: Int
    public let height: Int
    public let orientationDigest: String
    public let colorDigest: String

    public init(
        sourceFingerprint: String,
        exactTime: RationalTime,
        modelID: String,
        modelDigest: String,
        effectType: String,
        algorithmVersion: Int,
        parameterDigest: String,
        qualityTier: String,
        width: Int,
        height: Int,
        orientationDigest: String,
        colorDigest: String
    ) throws {
        let required = [sourceFingerprint, modelID, modelDigest, effectType, parameterDigest, qualityTier, orientationDigest, colorDigest]
        guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AIError.invalidJobState("AI frame effect cache identity fields must not be empty.")
        }
        guard algorithmVersion > 0 else {
            throw AIError.invalidJobState("AI frame effect algorithm version must be positive.")
        }
        guard width > 0, height > 0, width <= 16384, height <= 16384 else {
            throw AIError.invalidJobState("AI frame effect dimensions must be within 1...16384.")
        }
        self.sourceFingerprint = sourceFingerprint
        self.exactTime = exactTime
        self.modelID = modelID
        self.modelDigest = modelDigest
        self.effectType = effectType
        self.algorithmVersion = algorithmVersion
        self.parameterDigest = parameterDigest
        self.qualityTier = qualityTier
        self.width = width
        self.height = height
        self.orientationDigest = orientationDigest
        self.colorDigest = colorDigest
    }

    public var digest: String {
        let fields = [
            "source", sourceFingerprint,
            "time.value", String(exactTime.value),
            "time.timescale", String(exactTime.timescale),
            "model.id", modelID,
            "model.digest", modelDigest,
            "effect.type", effectType,
            "algorithm.version", String(algorithmVersion),
            "parameters.digest", parameterDigest,
            "quality", qualityTier,
            "width", String(width),
            "height", String(height),
            "orientation", orientationDigest,
            "color", colorDigest
        ]
        return StableAISHA256.hexDigest(Data(fields.joined(separator: "\u{1f}").utf8))
    }
}
