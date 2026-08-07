import Foundation
import VertexCore
import VertexMedia
import VertexRender

public enum ProjectMediaKind: String, Codable, CaseIterable, Sendable {
    case video
    case audio
    case image
    case unknown
}

public enum MediaAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case external
    case embedded
    case missing
}

public struct MediaLocator: Codable, Equatable, Sendable {
    public var relativeHint: String?
    public var embeddedPath: String?

    public init(relativeHint: String? = nil, embeddedPath: String? = nil) {
        self.relativeHint = relativeHint
        self.embeddedPath = embeddedPath
    }

    @available(*, deprecated, message: "Bookmark bytes belong in VertexProjectPersistence sidecars.")
    public init(
        relativeHint: String? = nil,
        bookmarkData: Data?,
        embeddedPath: String? = nil
    ) {
        self.relativeHint = relativeHint
        self.embeddedPath = embeddedPath
    }

    @available(*, deprecated, message: "Bookmark bytes belong in VertexProjectPersistence sidecars.")
    public var bookmarkData: Data? {
        get { nil }
        set { }
    }
}

public struct MediaReference: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var displayName: String
    public var originalFilename: String
    public var fileSize: Int64
    public var modificationDate: Date?
    public var contentFingerprint: String?
    public var locator: MediaLocator
    public var kind: ProjectMediaKind
    public var availabilityStatus: MediaAvailabilityStatus

    public init(
        id: VertexID = VertexID(),
        displayName: String,
        originalFilename: String,
        fileSize: Int64,
        modificationDate: Date?,
        contentFingerprint: String?,
        locator: MediaLocator = MediaLocator(),
        kind: ProjectMediaKind = .unknown,
        availabilityStatus: MediaAvailabilityStatus = .external
    ) {
        self.id = id
        self.displayName = displayName
        self.originalFilename = originalFilename
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.contentFingerprint = contentFingerprint
        self.locator = locator
        self.kind = kind
        self.availabilityStatus = availabilityStatus
    }

    public func validated() throws -> Self {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Media display name must not be empty.")
        }
        guard !originalFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Original media filename must not be empty.")
        }
        guard fileSize >= 0 else {
            throw ProjectError.invalidValue("Media file size must not be negative.")
        }
        if let embeddedPath = locator.embeddedPath {
            guard !embeddedPath.hasPrefix("/"),
                  !embeddedPath.split(separator: "/").contains("..") else {
                throw ProjectError.invalidPackagePath("Embedded media paths must remain inside the project package.")
            }
        }
        return self
    }

    public static func fixture(
        id: String = "50000000-0000-0000-0000-000000000099",
        name: String = "clip.mov",
        fileSize: Int64 = 100,
        fingerprint: String? = "fixture-fingerprint"
    ) -> MediaReference {
        MediaReference(
            id: VertexID(rawValue: id),
            displayName: name,
            originalFilename: name,
            fileSize: fileSize,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000),
            contentFingerprint: fingerprint,
            locator: MediaLocator(relativeHint: name),
            kind: .video,
            availabilityStatus: .external
        )
    }
}

public struct ProjectMetadata: Codable, Equatable, Sendable {
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var createdByAppVersion: String
    public var lastSavedByAppVersion: String

    public init(
        name: String,
        createdAt: Date,
        modifiedAt: Date,
        createdByAppVersion: String,
        lastSavedByAppVersion: String
    ) {
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.createdByAppVersion = createdByAppVersion
        self.lastSavedByAppVersion = lastSavedByAppVersion
    }
}

public struct ProjectSettings: Codable, Equatable, Sendable {
    public var frameRate: RationalTime
    public var color: ColorDescriptor

    public init(
        frameRate: RationalTime = RationalTime(value: 30, timescale: 1),
        color: ColorDescriptor = .rec709SDR(alphaMode: .straight)
    ) {
        self.frameRate = frameRate
        self.color = color
    }
}

public enum ProjectRenderParameter: String, Codable, CaseIterable, Sendable {
    case exposure
    case saturation
    case opacity
    case scale
    case translationX
    case translationY
}

public enum ProjectRenderBooleanParameter: String, Codable, CaseIterable, Sendable {
    case inverted
}

public struct ProjectRenderSettings: Codable, Equatable, Sendable {
    public var exposure: Double
    public var saturation: Double
    public var opacity: Double
    public var inverted: Bool
    public var scale: Double
    public var translationX: Double
    public var translationY: Double
    public var outputWidth: Int
    public var outputHeight: Int

    public init(
        exposure: Double = 0,
        saturation: Double = 1,
        opacity: Double = 1,
        inverted: Bool = false,
        scale: Double = 1,
        translationX: Double = 0,
        translationY: Double = 0,
        outputWidth: Int = 1080,
        outputHeight: Int = 1080
    ) {
        self.exposure = exposure
        self.saturation = saturation
        self.opacity = opacity
        self.inverted = inverted
        self.scale = scale
        self.translationX = translationX
        self.translationY = translationY
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
    }

    public var allValuesAreFinite: Bool {
        exposure.isFinite
            && saturation.isFinite
            && opacity.isFinite
            && scale.isFinite
            && translationX.isFinite
            && translationY.isFinite
    }

    public func value(for parameter: ProjectRenderParameter) -> Double {
        switch parameter {
        case .exposure: exposure
        case .saturation: saturation
        case .opacity: opacity
        case .scale: scale
        case .translationX: translationX
        case .translationY: translationY
        }
    }

    public mutating func set(_ value: Double, for parameter: ProjectRenderParameter) {
        switch parameter {
        case .exposure: exposure = value
        case .saturation: saturation = value
        case .opacity: opacity = value
        case .scale: scale = value
        case .translationX: translationX = value
        case .translationY: translationY = value
        }
    }

    public func validated() throws -> Self {
        guard allValuesAreFinite else {
            throw ProjectError.invalidValue("Render settings must contain only finite values.")
        }
        guard scale > 0 else {
            throw ProjectError.invalidValue("Render scale must be positive.")
        }
        guard outputWidth > 0,
              outputHeight > 0,
              outputWidth <= 8192,
              outputHeight <= 8192 else {
            throw ProjectError.invalidValue("Output dimensions must be between 1 and 8192 pixels.")
        }
        return self
    }
}

@available(*, deprecated, message: "Legacy schema construction compatibility only.")
public struct ProjectCompositionPlaceholder: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String

    public init(id: VertexID = VertexID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public static let currentAppVersion = "6.0.0"

    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: VertexID
    public var revision: UInt64
    public var metadata: ProjectMetadata
    public var settings: ProjectSettings
    public var mediaRegistry: [MediaReference]
    public var compositionRegistry: [ProjectComposition]
    public var layerRegistry: [ProjectLayer]
    public var activeCompositionID: VertexID?
    public var selectedLayerID: VertexID?
    public var selectedMediaID: VertexID?

    // Phase 5 Render Lab API remains session-local only while the Phase 6 UI is
    // reconnected. It is deliberately absent from CodingKeys and therefore can
    // never enter canonical project.json, autosaves, or pending snapshots.
    private var renderCompatibility: ProjectRenderSettings

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case minimumReaderVersion
        case projectID
        case revision
        case metadata
        case settings
        case mediaRegistry
        case compositionRegistry
        case layerRegistry
        case activeCompositionID
        case selectedLayerID
        case selectedMediaID
    }

    public init(
        schemaVersion: Int = ProjectDocument.currentSchemaVersion,
        minimumReaderVersion: Int = ProjectDocument.currentSchemaVersion,
        projectID: VertexID,
        revision: UInt64,
        metadata: ProjectMetadata,
        settings: ProjectSettings,
        mediaRegistry: [MediaReference],
        compositionRegistry: [ProjectComposition],
        layerRegistry: [ProjectLayer],
        activeCompositionID: VertexID?,
        selectedLayerID: VertexID?,
        selectedMediaID: VertexID?
    ) {
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.projectID = projectID
        self.revision = revision
        self.metadata = metadata
        self.settings = settings
        self.mediaRegistry = mediaRegistry
        self.compositionRegistry = compositionRegistry
        self.layerRegistry = layerRegistry
        self.activeCompositionID = activeCompositionID
        self.selectedLayerID = selectedLayerID
        self.selectedMediaID = selectedMediaID
        let active = activeCompositionID.flatMap { id in
            compositionRegistry.first { $0.id == id }
        }
        self.renderCompatibility = ProjectRenderSettings(
            outputWidth: active?.width ?? 1080,
            outputHeight: active?.height ?? 1080
        )
    }

    @available(*, deprecated, message: "Legacy Phase 5 construction compatibility only; values are not serialized as a render-settings field.")
    public init(
        schemaVersion: Int = ProjectDocument.currentSchemaVersion,
        minimumReaderVersion: Int = ProjectDocument.currentSchemaVersion,
        projectID: VertexID,
        revision: UInt64,
        metadata: ProjectMetadata,
        settings: ProjectSettings,
        mediaRegistry: [MediaReference],
        compositionRegistry placeholders: [ProjectCompositionPlaceholder],
        activeCompositionID: VertexID?,
        selectedMediaID: VertexID?,
        renderSettings: ProjectRenderSettings,
        appliedCommandIDs: [VertexID] = []
    ) {
        _ = appliedCommandIDs
        var compositions = placeholders.map {
            ProjectComposition(
                id: $0.id,
                name: $0.name,
                width: renderSettings.outputWidth,
                height: renderSettings.outputHeight,
                duration: RationalTime(value: 10, timescale: 1),
                frameRate: settings.frameRate,
                color: settings.color,
                backgroundColor: .transparent,
                layerIDs: []
            )
        }
        if compositions.isEmpty {
            let fallbackID = (try? DeterministicVertexID.derive(
                domain: "vertex.project.main-composition",
                components: [projectID.rawValue]
            )) ?? projectID
            compositions = [ProjectComposition(
                id: fallbackID,
                name: "Main Composition",
                width: renderSettings.outputWidth,
                height: renderSettings.outputHeight,
                duration: RationalTime(value: 10, timescale: 1),
                frameRate: settings.frameRate,
                color: settings.color,
                backgroundColor: .transparent,
                layerIDs: []
            )]
        }
        let normalizedActive = activeCompositionID.flatMap { candidate in
            compositions.contains(where: { $0.id == candidate }) ? candidate : nil
        } ?? compositions.first?.id
        self.init(
            schemaVersion: schemaVersion,
            minimumReaderVersion: minimumReaderVersion,
            projectID: projectID,
            revision: revision,
            metadata: metadata,
            settings: settings,
            mediaRegistry: mediaRegistry,
            compositionRegistry: compositions,
            layerRegistry: [],
            activeCompositionID: normalizedActive,
            selectedLayerID: nil,
            selectedMediaID: selectedMediaID
        )
        self.renderCompatibility = renderSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumReaderVersion = try container.decode(Int.self, forKey: .minimumReaderVersion)
        projectID = try container.decode(VertexID.self, forKey: .projectID)
        revision = try container.decode(UInt64.self, forKey: .revision)
        metadata = try container.decode(ProjectMetadata.self, forKey: .metadata)
        settings = try container.decode(ProjectSettings.self, forKey: .settings)
        mediaRegistry = try container.decode([MediaReference].self, forKey: .mediaRegistry)
        compositionRegistry = try container.decode([ProjectComposition].self, forKey: .compositionRegistry)
        layerRegistry = try container.decodeIfPresent([ProjectLayer].self, forKey: .layerRegistry) ?? []
        activeCompositionID = try container.decodeIfPresent(VertexID.self, forKey: .activeCompositionID)
        selectedLayerID = try container.decodeIfPresent(VertexID.self, forKey: .selectedLayerID)
        selectedMediaID = try container.decodeIfPresent(VertexID.self, forKey: .selectedMediaID)
        let active = activeCompositionID.flatMap { id in
            compositionRegistry.first { $0.id == id }
        }
        renderCompatibility = ProjectRenderSettings(
            outputWidth: active?.width ?? compositionRegistry.first?.width ?? 1080,
            outputHeight: active?.height ?? compositionRegistry.first?.height ?? 1080
        )
    }

    public func encode(to encoder: Encoder) throws {
        let canonical = normalized()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canonical.schemaVersion, forKey: .schemaVersion)
        try container.encode(canonical.minimumReaderVersion, forKey: .minimumReaderVersion)
        try container.encode(canonical.projectID, forKey: .projectID)
        try container.encode(canonical.revision, forKey: .revision)
        try container.encode(canonical.metadata, forKey: .metadata)
        try container.encode(canonical.settings, forKey: .settings)
        try container.encode(canonical.mediaRegistry, forKey: .mediaRegistry)
        try container.encode(canonical.compositionRegistry, forKey: .compositionRegistry)
        try container.encode(canonical.layerRegistry, forKey: .layerRegistry)
        try container.encodeIfPresent(canonical.activeCompositionID, forKey: .activeCompositionID)
        try container.encodeIfPresent(canonical.selectedLayerID, forKey: .selectedLayerID)
        try container.encodeIfPresent(canonical.selectedMediaID, forKey: .selectedMediaID)
    }

    public static func == (lhs: ProjectDocument, rhs: ProjectDocument) -> Bool {
        lhs.schemaVersion == rhs.schemaVersion
            && lhs.minimumReaderVersion == rhs.minimumReaderVersion
            && lhs.projectID == rhs.projectID
            && lhs.revision == rhs.revision
            && lhs.metadata == rhs.metadata
            && lhs.settings == rhs.settings
            && lhs.mediaRegistry == rhs.mediaRegistry
            && lhs.compositionRegistry == rhs.compositionRegistry
            && lhs.layerRegistry == rhs.layerRegistry
            && lhs.activeCompositionID == rhs.activeCompositionID
            && lhs.selectedLayerID == rhs.selectedLayerID
            && lhs.selectedMediaID == rhs.selectedMediaID
    }

    @available(*, deprecated, message: "Applied command IDs are active-session state only.")
    public var appliedCommandIDs: [VertexID] {
        get { [] }
        set { }
    }

    public var renderSettings: ProjectRenderSettings {
        get {
            var value = renderCompatibility
            if let activeCompositionID,
               let active = composition(id: activeCompositionID) {
                value.outputWidth = active.width
                value.outputHeight = active.height
            }
            return value
        }
        set {
            renderCompatibility = newValue
            guard let activeCompositionID,
                  let index = compositionRegistry.firstIndex(where: { $0.id == activeCompositionID }) else {
                return
            }
            compositionRegistry[index].width = newValue.outputWidth
            compositionRegistry[index].height = newValue.outputHeight
        }
    }

    public static func makeNew(
        id: VertexID = VertexID(),
        name: String,
        timestamp: Date = Date()
    ) throws -> ProjectDocument {
        let compositionID = try DeterministicVertexID.derive(
            domain: "vertex.project.main-composition",
            components: [id.rawValue]
        )
        let settings = ProjectSettings()
        let composition = ProjectComposition(
            id: compositionID,
            name: "Main Composition",
            width: 1080,
            height: 1080,
            duration: RationalTime(value: 10, timescale: 1),
            frameRate: settings.frameRate,
            color: settings.color,
            backgroundColor: .transparent,
            layerIDs: []
        )
        let document = ProjectDocument(
            projectID: id,
            revision: 0,
            metadata: ProjectMetadata(
                name: name,
                createdAt: timestamp,
                modifiedAt: timestamp,
                createdByAppVersion: currentAppVersion,
                lastSavedByAppVersion: currentAppVersion
            ),
            settings: settings,
            mediaRegistry: [],
            compositionRegistry: [composition],
            layerRegistry: [],
            activeCompositionID: composition.id,
            selectedLayerID: nil,
            selectedMediaID: nil
        )
        return try document.validated()
    }

    public static func makeFixture(
        timestamp: Date,
        media: [MediaReference]
    ) throws -> ProjectDocument {
        var document = try makeNew(
            id: VertexID(rawValue: "50000000-0000-0000-0000-000000000001"),
            name: "Fixture",
            timestamp: timestamp
        )
        document.mediaRegistry = media
        return try document.validated()
    }

    public func composition(id: VertexID) -> ProjectComposition? {
        compositionRegistry.first { $0.id == id }
    }

    public func layer(id: VertexID) -> ProjectLayer? {
        layerRegistry.first { $0.id == id }
    }

    public func layers(in compositionID: VertexID) -> [ProjectLayer] {
        guard let composition = composition(id: compositionID) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        return composition.layerIDs.compactMap { byID[$0] }
    }

    public func normalized() -> ProjectDocument {
        var copy = self
        copy.mediaRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.compositionRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.layerRegistry.sort { $0.id.rawValue < $1.id.rawValue }

        let canonicalActive: VertexID?
        if let candidate = copy.activeCompositionID,
           copy.compositionRegistry.contains(where: { $0.id == candidate }) {
            canonicalActive = candidate
        } else {
            canonicalActive = copy.compositionRegistry.first?.id
        }
        copy.activeCompositionID = canonicalActive

        if let selectedMediaID = copy.selectedMediaID,
           !copy.mediaRegistry.contains(where: { $0.id == selectedMediaID }) {
            copy.selectedMediaID = nil
        }
        if let selectedLayerID = copy.selectedLayerID {
            guard let selected = copy.layerRegistry.first(where: { $0.id == selectedLayerID }),
                  selected.compositionID == canonicalActive else {
                copy.selectedLayerID = nil
                return copy
            }
        }
        if let canonicalActive,
           let active = copy.compositionRegistry.first(where: { $0.id == canonicalActive }) {
            copy.renderCompatibility.outputWidth = active.width
            copy.renderCompatibility.outputHeight = active.height
        }
        return copy
    }

    public func nestedCompositionCycle() -> [VertexID]? {
        let layerByID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        var edges: [VertexID: [VertexID]] = [:]
        for composition in compositionRegistry {
            edges[composition.id] = composition.layerIDs.compactMap { layerID in
                guard let layer = layerByID[layerID],
                      case .composition(let target, _) = layer.source else {
                    return nil
                }
                return target
            }
        }

        var visited = Set<VertexID>()
        var active = Set<VertexID>()
        var stack: [VertexID] = []

        func visit(_ id: VertexID) -> [VertexID]? {
            if let index = stack.firstIndex(of: id) {
                return Array(stack[index...]) + [id]
            }
            if visited.contains(id) { return nil }
            visited.insert(id)
            active.insert(id)
            stack.append(id)
            for target in edges[id] ?? [] {
                if active.contains(target), let index = stack.firstIndex(of: target) {
                    return Array(stack[index...]) + [target]
                }
                if let cycle = visit(target) {
                    return cycle
                }
            }
            _ = stack.popLast()
            active.remove(id)
            return nil
        }

        for composition in compositionRegistry {
            if let cycle = visit(composition.id) {
                return cycle
            }
        }
        return nil
    }

    public func validated() throws -> ProjectDocument {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ProjectError.unsupportedSchema(found: schemaVersion, supported: Self.currentSchemaVersion)
        }
        guard minimumReaderVersion <= schemaVersion else {
            throw ProjectError.invalidValue("Minimum reader version cannot exceed the schema version.")
        }
        guard !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Project name must not be empty.")
        }
        guard settings.frameRate > .zero else {
            throw ProjectError.invalidValue("Project frame rate must be positive.")
        }
        _ = try renderCompatibility.validated()
        for reference in mediaRegistry {
            _ = try reference.validated()
        }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count else {
            throw ProjectError.duplicateIdentity("media")
        }
        guard !compositionRegistry.isEmpty else {
            throw ProjectError.invalidValue("A project must contain at least one composition.")
        }
        guard Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else {
            throw ProjectError.duplicateIdentity("composition")
        }
        guard Set(layerRegistry.map(\.id)).count == layerRegistry.count else {
            throw ProjectError.duplicateIdentity("layer")
        }

        let layerByID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        for composition in compositionRegistry {
            _ = try composition.validated(layerByID: layerByID)
        }
        let orderedIDs = compositionRegistry.flatMap(\.layerIDs)
        guard orderedIDs.count == layerRegistry.count,
              Set(orderedIDs) == Set(layerRegistry.map(\.id)) else {
            throw ProjectError.invalidValue("Every layer must appear exactly once in its owning composition order.")
        }
        for layer in layerRegistry {
            _ = try layer.validated(in: self)
        }

        guard let activeCompositionID,
              compositionRegistry.contains(where: { $0.id == activeCompositionID }) else {
            throw ProjectError.invalidValue("An active composition must exist in the composition registry.")
        }
        if let selectedMediaID,
           !mediaRegistry.contains(where: { $0.id == selectedMediaID }) {
            throw ProjectError.invalidValue("Selected media must exist in the media registry.")
        }
        if let selectedLayerID {
            guard let selected = layer(id: selectedLayerID),
                  selected.compositionID == activeCompositionID else {
                throw ProjectError.invalidValue("Selected layer must exist in the active composition.")
            }
        }
        if let cycle = nestedCompositionCycle() {
            throw ProjectError.invalidValue(
                "Nested composition cycle: \(cycle.map(\.rawValue).joined(separator: " -> "))."
            )
        }
        return self
    }
}

public enum ProjectIntegrityStatus: String, Codable, CaseIterable, Sendable {
    case valid
    case recovered
    case damaged
}

public struct ProjectManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: VertexID
    public var createdByAppVersion: String
    public var lastSavedByAppVersion: String
    public var projectRevision: UInt64
    public var projectChecksum: String
    public var committedJournalSequence: UInt64
    public var lastSuccessfulSave: Date
    public var integrityStatus: ProjectIntegrityStatus

    public init(
        document: ProjectDocument,
        projectChecksum: String,
        committedJournalSequence: UInt64,
        lastSuccessfulSave: Date,
        integrityStatus: ProjectIntegrityStatus = .valid
    ) {
        schemaVersion = document.schemaVersion
        minimumReaderVersion = document.minimumReaderVersion
        projectID = document.projectID
        createdByAppVersion = document.metadata.createdByAppVersion
        lastSavedByAppVersion = document.metadata.lastSavedByAppVersion
        projectRevision = document.revision
        self.projectChecksum = projectChecksum
        self.committedJournalSequence = committedJournalSequence
        self.lastSuccessfulSave = lastSuccessfulSave
        self.integrityStatus = integrityStatus
    }
}
