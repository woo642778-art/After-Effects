import Foundation

public struct AICapabilityProfile: Codable, Equatable, Sendable {
    public var supportsMaxQualityByHardwareClass: Bool
    public var memoryBudgetBytes: UInt64
    public var thermalRestricted: Bool
    public var neuralEngineAvailable: Bool

    public init(
        supportsMaxQualityByHardwareClass: Bool,
        memoryBudgetBytes: UInt64,
        thermalRestricted: Bool,
        neuralEngineAvailable: Bool
    ) {
        self.supportsMaxQualityByHardwareClass = supportsMaxQualityByHardwareClass
        self.memoryBudgetBytes = memoryBudgetBytes
        self.thermalRestricted = thermalRestricted
        self.neuralEngineAvailable = neuralEngineAvailable
    }

    public static let conservative = AICapabilityProfile(
        supportsMaxQualityByHardwareClass: false,
        memoryBudgetBytes: 768_000_000,
        thermalRestricted: false,
        neuralEngineAvailable: false
    )
}
