import VertexCore

public enum ExportFrameRatePreset: String, Codable, Sendable, CaseIterable {
    case matchComposition
    case fps23976
    case fps24
    case fps25
    case fps2997
    case fps30
    case fps50
    case fps5994
    case fps60
    case fps120
    case custom

    public var exactFrameRate: RationalTime? {
        switch self {
        case .matchComposition, .custom:
            nil
        case .fps23976:
            RationalTime(value: 24_000, timescale: 1_001)
        case .fps24:
            RationalTime(value: 24, timescale: 1)
        case .fps25:
            RationalTime(value: 25, timescale: 1)
        case .fps2997:
            RationalTime(value: 30_000, timescale: 1_001)
        case .fps30:
            RationalTime(value: 30, timescale: 1)
        case .fps50:
            RationalTime(value: 50, timescale: 1)
        case .fps5994:
            RationalTime(value: 60_000, timescale: 1_001)
        case .fps60:
            RationalTime(value: 60, timescale: 1)
        case .fps120:
            RationalTime(value: 120, timescale: 1)
        }
    }
}

public struct ResolvedExportOutputSettings: Equatable, Sendable {
    public var dimensions: ExportDimensions
    public var frameRate: RationalTime

    public init(dimensions: ExportDimensions, frameRate: RationalTime) {
        self.dimensions = dimensions
        self.frameRate = frameRate
    }
}

public struct ExportOutputSettings: Equatable, Sendable {
    public var resolution: ExportResolutionPreset
    public var customDimensions: ExportDimensions
    public var frameRate: ExportFrameRatePreset
    public var customFrameRate: RationalTime?

    public init(
        resolution: ExportResolutionPreset = .matchComposition,
        customDimensions: ExportDimensions,
        frameRate: ExportFrameRatePreset = .matchComposition,
        customFrameRate: RationalTime? = nil
    ) {
        self.resolution = resolution
        self.customDimensions = customDimensions
        self.frameRate = frameRate
        self.customFrameRate = customFrameRate
    }

    public func resolved(
        compositionDimensions: ExportDimensions,
        compositionFrameRate: RationalTime
    ) throws -> ResolvedExportOutputSettings {
        let dimensions: ExportDimensions
        switch resolution {
        case .matchComposition:
            dimensions = compositionDimensions
        case .custom:
            dimensions = customDimensions
        default:
            guard let preset = resolution.dimensions else {
                throw ExportValidationError.invalidDimensions
            }
            dimensions = preset
        }
        guard (1...8192).contains(dimensions.width), (1...8192).contains(dimensions.height) else {
            throw ExportValidationError.invalidDimensions
        }

        let resolvedFrameRate: RationalTime
        switch frameRate {
        case .matchComposition:
            resolvedFrameRate = compositionFrameRate
        case .custom:
            guard let customFrameRate else { throw ExportValidationError.invalidFrameRate }
            resolvedFrameRate = customFrameRate
        default:
            guard let preset = frameRate.exactFrameRate else { throw ExportValidationError.invalidFrameRate }
            resolvedFrameRate = preset
        }
        guard resolvedFrameRate > .zero,
              resolvedFrameRate.seconds.isFinite,
              resolvedFrameRate.seconds <= 240 else {
            throw ExportValidationError.invalidFrameRate
        }

        return ResolvedExportOutputSettings(dimensions: dimensions, frameRate: resolvedFrameRate)
    }
}
