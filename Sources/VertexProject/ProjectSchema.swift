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
    public var bookmarkData: Data?
    public var embeddedPath: String?

    public init(relativeHint: String? = nil, bookmarkData: Data? = nil, embeddedPath: String? = nil) {
        self.relativeHint = relativeHint
        self.bookmarkData = bookmarkData
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
            guard !embeddedPath.hasPrefix("/"), !embeddedPath.split(separator: "/").contains("..") else {
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

    public init(name: String, createdAt: Date, modifiedAt: Date, createdByAppVersion: String, lastSavedByAppVersion: String) {
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

    public init(frameRate: RationalTime = RationalTime(value: 30, timescale: 1), color: ColorDescriptor = .rec709SDR(alphaMode: .straight)) {
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

public struct ProjectCompositionPlaceholder: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String

    public init(id: VertexID = VertexID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let currentAppVersion = "5.0.0"

    public var schemaVersion: Int
    public var minimumReaderVersion: Int
    public var projectID: VertexID
    public var revision: UInt64
    public var metadata: ProjectMetadata
    public var settings: ProjectSettings
    public var mediaRegistry: [MediaReference]
    public var compositionRegistry: [ProjectCompositionPlaceholder]
    public var activeCompositionID: VertexID?
    public var selectedMediaID: VertexID?
    public var renderSettings: ProjectRenderSettings
    public var appliedCommandIDs: [VertexID]

    public init(
        schemaVersion: Int = ProjectDocument.currentSchemaVersion,
        minimumReaderVersion: Int = ProjectDocument.currentSchemaVersion,
        projectID: VertexID,
        revision: UInt64,
        metadata: ProjectMetadata,
        settings: ProjectSettings,
        mediaRegistry: [MediaReference],
        compositionRegistry: [ProjectCompositionPlaceholder],
        activeCompositionID: VertexID?,
        selectedMediaID: VertexID?,
        renderSettings: ProjectRenderSettings,
        appliedCommandIDs: [VertexID]
    ) {
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.projectID = projectID
        self.revision = revision
        self.metadata = metadata
        self.settings = settings
        self.mediaRegistry = mediaRegistry
        self.compositionRegistry = compositionRegistry
        self.activeCompositionID = activeCompositionID
        self.selectedMediaID = selectedMediaID
        self.renderSettings = renderSettings
        self.appliedCommandIDs = appliedCommandIDs
    }

    public static func makeNew(id: VertexID = VertexID(), name: String, timestamp: Date = Date()) throws -> ProjectDocument {
        let document = ProjectDocument(
            projectID: id,
            revision: 0,
            metadata: ProjectMetadata(name: name, createdAt: timestamp, modifiedAt: timestamp, createdByAppVersion: currentAppVersion, lastSavedByAppVersion: currentAppVersion),
            settings: ProjectSettings(),
            mediaRegistry: [],
            compositionRegistry: [],
            activeCompositionID: nil,
            selectedMediaID: nil,
            renderSettings: ProjectRenderSettings(),
            appliedCommandIDs: []
        )
        return try document.validated()
    }

    public static func makeFixture(timestamp: Date, media: [MediaReference]) throws -> ProjectDocument {
        var document = try makeNew(id: VertexID(rawValue: "50000000-0000-0000-0000-000000000001"), name: "Fixture", timestamp: timestamp)
        document.mediaRegistry = media
        return try document.validated()
    }

    public func normalized() -> ProjectDocument {
        var copy = self
        copy.mediaRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.compositionRegistry.sort { $0.id.rawValue < $1.id.rawValue }
        copy.appliedCommandIDs = Array(Set(copy.appliedCommandIDs)).sorted { $0.rawValue < $1.rawValue }
        return copy
    }

    public func validated() throws -> ProjectDocument {
        guard schemaVersion == Self.currentSchemaVersion else { throw ProjectError.unsupportedSchema(found: schemaVersion, supported: Self.currentSchemaVersion) }
        guard minimumReaderVersion <= schemaVersion else { throw ProjectError.invalidValue("Minimum reader version cannot exceed the schema version.") }
        guard !metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProjectError.invalidValue("Project name must not be empty.") }
        _ = try renderSettings.validated()
        for reference in mediaRegistry { _ = try reference.validated() }
        guard Set(mediaRegistry.map(\.id)).count == mediaRegistry.count else { throw ProjectError.duplicateIdentity("media") }
        guard Set(compositionRegistry.map(\.id)).count == compositionRegistry.count else { throw ProjectError.duplicateIdentity("composition") }
        if let selectedMediaID, !mediaRegistry.contains(where: { $0.id == selectedMediaID }) { throw ProjectError.invalidValue("Selected media must exist in the media registry.") }
        if let activeCompositionID, !compositionRegistry.contains(where: { $0.id == activeCompositionID }) { throw ProjectError.invalidValue("Active composition must exist in the composition registry.") }
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

    public init(document: ProjectDocument, projectChecksum: String, committedJournalSequence: UInt64, lastSuccessfulSave: Date, integrityStatus: ProjectIntegrityStatus = .valid) {
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
