import Foundation

public enum AIQualityTier: String, Codable, CaseIterable, Sendable {
    case preview
    case balanced
    case maxQuality
}

public struct AIQualityDecision: Codable, Equatable, Sendable {
    public var requested: AIQualityTier
    public var effective: AIQualityTier
    public var fallbackReason: String?

    public init(requested: AIQualityTier, effective: AIQualityTier, fallbackReason: String? = nil) {
        self.requested = requested
        self.effective = effective
        self.fallbackReason = fallbackReason
    }
}

public enum AIQualityPolicy {
    public static let minimumBalancedMemoryBudgetBytes: UInt64 = 1_250_000_000
    public static let minimumMaxQualityMemoryBudgetBytes: UInt64 = 3_000_000_000

    public static func decide(
        requested: AIQualityTier,
        profile: AICapabilityProfile
    ) -> AIQualityDecision {
        switch requested {
        case .preview:
            return AIQualityDecision(requested: requested, effective: .preview)

        case .balanced:
            guard !profile.thermalRestricted else {
                return AIQualityDecision(
                    requested: requested,
                    effective: .preview,
                    fallbackReason: "Thermal pressure requires Preview quality."
                )
            }
            guard profile.memoryBudgetBytes >= minimumBalancedMemoryBudgetBytes else {
                return AIQualityDecision(
                    requested: requested,
                    effective: .preview,
                    fallbackReason: "Available AI memory budget is below the Balanced threshold."
                )
            }
            return AIQualityDecision(requested: requested, effective: .balanced)

        case .maxQuality:
            if profile.thermalRestricted {
                return fallbackFromMax(requested: requested, profile: profile, reason: "Thermal pressure prevents Max Quality.")
            }
            if !profile.supportsMaxQualityByHardwareClass {
                return fallbackFromMax(requested: requested, profile: profile, reason: "This hardware class is not eligible for Max Quality.")
            }
            if !profile.neuralEngineAvailable {
                return fallbackFromMax(requested: requested, profile: profile, reason: "A compatible Neural Engine path is unavailable.")
            }
            if profile.memoryBudgetBytes < minimumMaxQualityMemoryBudgetBytes {
                return fallbackFromMax(requested: requested, profile: profile, reason: "Available AI memory budget is below the Max Quality threshold.")
            }
            return AIQualityDecision(requested: requested, effective: .maxQuality)
        }
    }

    private static func fallbackFromMax(
        requested: AIQualityTier,
        profile: AICapabilityProfile,
        reason: String
    ) -> AIQualityDecision {
        let balancedAllowed = !profile.thermalRestricted
            && profile.memoryBudgetBytes >= minimumBalancedMemoryBudgetBytes
        return AIQualityDecision(
            requested: requested,
            effective: balancedAllowed ? .balanced : .preview,
            fallbackReason: reason
        )
    }
}
