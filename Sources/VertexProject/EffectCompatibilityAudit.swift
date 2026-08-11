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
    public var id: String { family.rawValue }
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
    public var id: String { type.rawValue }
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

    /// The implemented-effect table is derived from the authoritative executable
    /// ProjectEffectType enum so adding a real effect cannot silently leave the
    /// compatibility audit stale. The large 1,568-entry reference catalog remains
    /// separate and is never treated as executable merely because it is indexed.
    public static let implementedEffects: [VertexImplementedEffectSummary] = ProjectEffectType.allCases.map { type in
        VertexImplementedEffectSummary(
            type: type,
            status: type.isNativePixelEffect ? .nativeImplemented : .aiImplemented,
            displayName: type.rawValue
        )
    }

    public static var implementedCount: Int { implementedEffects.count }
    public static var remainingIndexedCount: Int { indexedEntryCount - implementedCount }

    public static func validate() throws {
        guard families.reduce(0, { $0 + $1.indexedEntryCount }) == indexedEntryCount else {
            throw ProjectError.invalidValue("Compatibility family totals must equal the indexed catalog total.")
        }
        let mappedTypes = Set(implementedEffects.map { $0.type.rawValue })
        let declaredTypes = Set(ProjectEffectType.allCases.map { $0.rawValue })
        guard mappedTypes.count == implementedEffects.count, mappedTypes == declaredTypes else {
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
