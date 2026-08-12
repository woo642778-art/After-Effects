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

// Schema-1 decoding/migration compatibility only. Schema 4 does not persist this
// object as project-global edit state.
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
        exposure.isFinite && saturation.isFinite && opacity.isFinite && scale.isFinite && translationX.isFinite && translationY.isFinite
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
        guard allValuesAreFinite else { throw ProjectError.invalidValue("Render settings must contain only finite values.") }
        guard scale > 0 else { throw ProjectError.invalidValue("Render scale must be positive.") }
        guard outputWidth > 0, outputHeight > 0, outputWidth <= 8192, outputHeight <= 8192 else {
            throw ProjectError.invalidValue("Output dimensions must be between 1 and 8192 pixels.")
        }
        return self
    }
}

@available(*, deprecated, message: "Schema 1 decode compatibility only")
public struct ProjectCompositionPlaceholder: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String

    public init(id: VertexID = VertexID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 5
    public static let currentAppVersion = "17.0.0"

    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: VertexID
    public var revision: UInt64
    public var metadata: ProjectMetadata
    public var settings: ProjectSettings
    public var mediaRegistry: [MediaReference]
    public var compositionRegistry: [ProjectComposition]
    public var layerRegistry: [ProjectLayer]
    public var aiAssetRegistry: [ProjectAIAsset]
    public var activeCompositionID: VertexID?
    public var selectedLayerID: VertexID?
    public var selectedMediaID: VertexID?

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
        aiAssetRegistry: [ProjectAIAsset] = [],
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
        self.aiAssetRegistry = aiAssetRegistry
        self.activeCompositionID = activeCompositionID
        self.selectedLayerID = selectedLayerID
        self.selectedMediaID = selectedMediaID
    }

    public static func makeNew(
        id: VertexID = VertexID(),
        name: String,
        timestamp: Date = Date()
    ) throws -> ProjectDocument {
        try ProjectDocument(
            projectID: id,
            revision: 0,
            metadata: ProjectMetadata(
                name: name,
                createdAt: timestamp,
                modifiedAt: timestamp,
                createdByAppVersion: currentAppVersion,
                lastSavedByAppVersion: currentAppVersion
            ),
            settings: ProjectSettings(),
            mediaRegistry: [],
            compositionRegistry: [],
            layerRegistry: [],
            aiAssetRegistry: [],
            activeCompositionID: nil,
            selectedLayerID: nil,
            selectedMediaID: nil
        ).validated()
    }

    public static func makeFixture(timestamp: Date, media: [MediaReference]) throws -> ProjectDocument {
        let projectID = VertexID(rawValue: "50000000-0000-0000-0000-000000000001")
        let compositionID = try DeterministicVertexID.derive(
            domain: "schema2.main-composition",
            components: [projectID.rawValue]
        )
        let composition = ProjectComposition(
            id: compositionID,
            name: "Main Composition",
            width: 1080,
            height: 1080,
            duration: RationalTime(value: 10, timescale: 1),
            frameRate: RationalTime(value: 30, timescale: 1),
            color: .rec709SDR(alphaMode: .straight),
            backgroundColor: .transparent,
            layerIDs: []
        )
        return try ProjectDocument(
            projectID: projectID,
            revision: 0,
            metadata: ProjectMetadata(
                name: "Fixture",
                createdAt: timestamp,
                modifiedAt: timestamp,
                createdByAppVersion: currentAppVersion,
                lastSavedByAppVersion: currentAppVersion
            ),
            settings: ProjectSettings(),
            mediaRegistry: media,
            compositionRegistry: [composition],
            layerRegistry: [],
            aiAssetRegistry: [],
            activeCompositionID: compositionID,
            selectedLayerID: nil,
            selectedMediaID: nil
        ).validated()
    }

    public func composition(id: VertexID) -> ProjectComposition? {
        compositionRegistry.first { $0.id == id }
    }

    public func layer(id: VertexID) -> ProjectLayer? {
        layerRegistry.first { $0.id == id }
    }

    public func aiAsset(id: VertexID) -> ProjectAIAsset? {
        aiAssetRegistry.first { $0.id == id }
    }

    public func layers(in compositionID: VertexID) -> [ProjectLayer] {
        guard let composition = composition(id: compositionID) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        return composition.layerIDs.compactMap { byID[$0] }
    }

    @available(*, deprecated, message: "Use composition and layer properties directly")
    public var renderSettings: ProjectRenderSettings {
        get {
            let activeComposition: ProjectComposition? = activeCompositionID.flatMap { self.composition(id: $0) }
            let selectedEditLayer: ProjectLayer? = selectedLayerID.flatMap { self.layer(id: $0) }
            let fallbackMediaLayer: ProjectLayer? = activeComposition?.layerIDs
                .compactMap { self.layer(id: $0) }
                .first { candidate in
                    if case .media = candidate.source { return true }
                    return false
                }
            let editLayer = selectedEditLayer ?? fallbackMediaLayer

            var exposure = 0.0
            var saturation = 1.0
            var inverted = false
            if let editLayer {
                for operation in editLayer.operations {
                    switch operation {
                    case .exposure(let value): exposure = value
                    case .saturation(let value): saturation = value
                    case .invert(let value): inverted = value
                    }
                }
            }
            return ProjectRenderSettings(
                exposure: exposure,
                saturation: saturation,
                opacity: editLayer?.transform.opacity ?? 1,
                inverted: inverted,
                scale: editLayer?.transform.scaleX ?? 1,
                translationX: (editLayer?.transform.positionX ?? 0.5) - 0.5,
                translationY: (editLayer?.transform.positionY ?? 0.5) - 0.5,
                outputWidth: activeComposition?.width ?? 1080,
                outputHeight: activeComposition?.height ?? 1080
            )
        }
        set {
            if let compositionID = activeCompositionID,
               let compositionIndex = compositionRegistry.firstIndex(where: { $0.id == compositionID }) {
                compositionRegistry[compositionIndex].width = newValue.outputWidth
                compositionRegistry[compositionIndex].height = newValue.outputHeight
            }
            guard let layerID = selectedLayerID
                    ?? activeCompositionID.flatMap({ id in
                        self.composition(id: id)?.layerIDs.first(where: { candidate in
                            guard let candidateLayer = self.layer(id: candidate) else { return false }
                            if case .media = candidateLayer.source { return true }
                            return false
                        })
                    }),
                  let layerIndex = layerRegistry.firstIndex(where: { $0.id == layerID }) else { return }
            layerRegistry[layerIndex].transform.opacity = newValue.opacity
            layerRegistry[layerIndex].transform.scaleX = newValue.scale
            layerRegistry[layerIndex].transform.scaleY = newValue.scale
            layerRegistry[layerIndex].transform.positionX = 0.5 + newValue.translationX
            layerRegistry[layerIndex].transform.positionY = 0.5 + newValue.translationY
            layerRegistry[layerIndex].operations = [
                .exposure(stops: newValue.exposure),
                .saturation(value: newValue.saturation),
                .invert(enabled: newValue.inverted)
            ]
        }
    }

    public func normalized() -> ProjectDocument {
        var copy = self
        copy.mediaRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.compositionRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.layerRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.aiAssetRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        return copy
    }

    public func nestedCompositionCycle() -> [VertexID]? {
        let layerByID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        var edges: [VertexID: [VertexID]] = [:]
        for composition in compositionRegistry {
            edges[composition.id] = composition.layerIDs.compactMap { layerID in
                guard let layer = layerByID[layerID],
                      case .composition(let target, _) = layer.source else { return nil }
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
                if let cycle = visit(target) { return cycle }
            }
            _ = stack.popLast()
            active.remove(id)
            return nil
        }

        for composition in compositionRegistry {
            if let cycle = visit(composition.id) { return cycle }
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
        for reference in mediaRegistry { _ = try reference.validated() }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count else { throw ProjectError.duplicateIdentity("media") }
        guard Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else { throw ProjectError.duplicateIdentity("composition") }
        guard Set(layerRegistry.map(\.id)).count == layerRegistry.count else { throw ProjectError.duplicateIdentity("layer") }
        guard Set(aiAssetRegistry.map(\.id)).count == aiAssetRegistry.count else { throw ProjectError.duplicateIdentity("AI asset") }
        guard Set(aiAssetRegistry.map(\.outputMediaID)).count == aiAssetRegistry.count else {
            throw ProjectError.invalidValue("Each AI asset must own a unique output media reference.")
        }

        let layerByID = Dictionary(uniqueKeysWithValues: layerRegistry.map { ($0.id, $0) })
        var owned = Set<VertexID>()
        for composition in compositionRegistry {
            _ = try composition.validated(layerByID: layerByID)
            for layerID in composition.layerIDs {
                guard owned.insert(layerID).inserted else {
                    throw ProjectError.invalidValue("A layer may belong to only one composition order.")
                }
            }
        }
        guard owned.count == layerRegistry.count else {
            throw ProjectError.invalidValue("Every layer must appear exactly once in its owner composition order.")
        }
        for layer in layerRegistry { _ = try layer.validated(in: self) }
        for aiAsset in aiAssetRegistry { _ = try aiAsset.validated(in: self) }

        if let selectedMediaID, !mediaRegistry.contains(where: { $0.id == selectedMediaID }) {
            throw ProjectError.invalidValue("Selected media must exist in the media registry.")
        }
        if let activeCompositionID, !compositionRegistry.contains(where: { $0.id == activeCompositionID }) {
            throw ProjectError.invalidValue("Active composition must exist in the composition registry.")
        }
        if let selectedLayerID, !layerRegistry.contains(where: { $0.id == selectedLayerID }) {
            throw ProjectError.invalidValue("Selected layer must exist in the layer registry.")
        }
        if let cycle = nestedCompositionCycle() {
            throw ProjectError.nestedCompositionCycle(cycle.map(\.rawValue))
        }
        return self
    }
}
