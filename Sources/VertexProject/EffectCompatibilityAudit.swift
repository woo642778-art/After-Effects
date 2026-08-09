import Foundation

public enum EffectCompatibilityStatus: String, Codable, CaseIterable, Sendable {
    case nativeImplemented
    case aiImplemented
    case cleanRoomPlanned
    case workflowExtension
    case scriptCommand
    case legacyReference
    case unsupportedExternal
}

public enum EffectCompatibilityFamily: String, Codable, CaseIterable, Sendable {
    case adobeDefault
    case continuum
    case sapphire
    case redGiantUniverse
    case extensions
    case scripts
    case otherIndexed
}

public struct EffectCompatibilityFamilySummary: Codable, Equatable, Sendable, Identifiable {
    public var id: EffectCompatibilityFamily { family }
    public let family: EffectCompatibilityFamily
    public let indexedEntryCount: Int
    public let defaultStatus: EffectCompatibilityStatus

    public init(
        family: EffectCompatibilityFamily,
        indexedEntryCount: Int,
        defaultStatus: EffectCompatibilityStatus
    ) {
        self.family = family
        self.indexedEntryCount = indexedEntryCount
        self.defaultStatus = defaultStatus
    }
}

public struct VertexImplementedEffectSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: ProjectEffectType { type }
    public let type: ProjectEffectType
    public let status: EffectCompatibilityStatus
    public let displayName: String

    public init(type: ProjectEffectType, status: EffectCompatibilityStatus, displayName: String) {
        self.type = type
        self.status = status
        self.displayName = displayName
    }
}

public enum EffectCompatibilityAudit {
    /// Source-document total. This is an indexed-reference count, not an implementation count.
    public static let indexedEntryCount = 1_568

    public static let families: [EffectCompatibilityFamilySummary] = [
        .init(family: .adobeDefault, indexedEntryCount: 290, defaultStatus: .cleanRoomPlanned),
        .init(family: .continuum, indexedEntryCount: 332, defaultStatus: .cleanRoomPlanned),
        .init(family: .sapphire, indexedEntryCount: 296, defaultStatus: .cleanRoomPlanned),
        .init(family: .redGiantUniverse, indexedEntryCount: 138, defaultStatus: .cleanRoomPlanned),
        .init(family: .extensions, indexedEntryCount: 47, defaultStatus: .workflowExtension),
        .init(family: .scripts, indexedEntryCount: 39, defaultStatus: .scriptCommand),
        // The reference document reports 1,568 indexed entries while the six named
        // family totals above account for 1,142. Preserve the remaining 426 as an
        // explicit unclassified bucket rather than inventing family assignments.
        .init(family: .otherIndexed, indexedEntryCount: 426, defaultStatus: .legacyReference)
    ]

    public static let implementedEffects: [VertexImplementedEffectSummary] = [
        .init(type: .depthMap, status: .aiImplemented, displayName: "Depth Map"),
        .init(type: .cutout, status: .aiImplemented, displayName: "Cutout"),
        .init(type: .upscale, status: .aiImplemented, displayName: "Upscale"),
        .init(type: .restore, status: .aiImplemented, displayName: "Restore"),
        .init(type: .gaussianBlur, status: .nativeImplemented, displayName: "Gaussian Blur"),
        .init(type: .sharpen, status: .nativeImplemented, displayName: "Sharpen"),
        .init(type: .exposure, status: .nativeImplemented, displayName: "Exposure"),
        .init(type: .colorControls, status: .nativeImplemented, displayName: "Color Controls"),
        .init(type: .hueAdjust, status: .nativeImplemented, displayName: "Hue Adjust"),
        .init(type: .invert, status: .nativeImplemented, displayName: "Invert")
    ]

    public static var implementedCount: Int { implementedEffects.count }
    public static var remainingIndexedCount: Int { indexedEntryCount - implementedCount }

    public static func validate() throws {
        guard families.reduce(0, { $0 + $1.indexedEntryCount }) == indexedEntryCount else {
            throw ProjectError.invalidValue("Compatibility family totals must equal the indexed catalog total.")
        }
        guard Set(implementedEffects.map(\.type)) == Set(ProjectEffectType.allCases) else {
            throw ProjectError.invalidValue("Every implemented ProjectEffectType must have exactly one compatibility status.")
        }
        guard implementedEffects.filter({ $0.status == .nativeImplemented }).allSatisfy({ $0.type.isNativePixelEffect }) else {
            throw ProjectError.invalidValue("Native compatibility entries must map to native pixel effects.")
        }
        guard implementedEffects.filter({ $0.status == .aiImplemented }).allSatisfy({ !$0.type.isNativePixelEffect }) else {
            throw ProjectError.invalidValue("AI compatibility entries must map to AI effects.")
        }
    }
}
