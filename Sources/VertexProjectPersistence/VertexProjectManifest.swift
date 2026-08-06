import Foundation
import VertexCore
import VertexProject

public struct VertexProjectManifest: Codable, Equatable, Sendable {
    public static let currentPackageFormatVersion = 1

    public let packageFormatVersion: Int
    public let schemaVersion: Int
    public let minimumReaderVersion: Int
    public let projectID: VertexID
    public let projectRevision: UInt64
    public let projectChecksum: String
    public let createdByAppVersion: String
    public let lastSavedByAppVersion: String
    public let lastSuccessfulSave: Date

    public init(
        packageFormatVersion: Int = Self.currentPackageFormatVersion,
        schemaVersion: Int,
        minimumReaderVersion: Int,
        projectID: VertexID,
        projectRevision: UInt64,
        projectChecksum: String,
        createdByAppVersion: String,
        lastSavedByAppVersion: String,
        lastSuccessfulSave: Date
    ) throws {
        guard packageFormatVersion == Self.currentPackageFormatVersion else {
            throw ProjectPersistenceError.invalidManifest(
                "Unsupported package format version \(packageFormatVersion)."
            )
        }
        guard schemaVersion > 0,
              minimumReaderVersion > 0,
              minimumReaderVersion <= schemaVersion else {
            throw ProjectPersistenceError.invalidManifest("Schema reader bounds are invalid.")
        }
        guard projectChecksum.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else {
            throw ProjectPersistenceError.invalidManifest("Project checksum is not lowercase SHA-256.")
        }
        guard !createdByAppVersion.isEmpty, !lastSavedByAppVersion.isEmpty else {
            throw ProjectPersistenceError.invalidManifest("Application versions must not be empty.")
        }

        self.packageFormatVersion = packageFormatVersion
        self.schemaVersion = schemaVersion
        self.minimumReaderVersion = minimumReaderVersion
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.projectChecksum = projectChecksum
        self.createdByAppVersion = createdByAppVersion
        self.lastSavedByAppVersion = lastSavedByAppVersion
        self.lastSuccessfulSave = lastSuccessfulSave
    }

    public init(
        document: ProjectDocument,
        projectData: Data,
        savedAt: Date
    ) throws {
        let validated = try document.validated()
        let checksum = DeterministicProjectCodec().checksum(data: projectData)
        let decoded = try DeterministicProjectCodec().decode(projectData)
        guard decoded == validated else {
            throw ProjectPersistenceError.invalidManifest(
                "Project bytes do not encode the supplied document."
            )
        }
        try self.init(
            schemaVersion: validated.schemaVersion,
            minimumReaderVersion: validated.minimumReaderVersion,
            projectID: validated.projectID,
            projectRevision: validated.revision,
            projectChecksum: checksum,
            createdByAppVersion: validated.metadata.createdByAppVersion,
            lastSavedByAppVersion: validated.metadata.lastSavedByAppVersion,
            lastSuccessfulSave: savedAt
        )
    }

    public func validate(document: ProjectDocument, projectData: Data) throws {
        guard packageFormatVersion == Self.currentPackageFormatVersion else {
            throw ProjectPersistenceError.invalidManifest(
                "Unsupported package format version \(packageFormatVersion)."
            )
        }
        guard schemaVersion == document.schemaVersion,
              minimumReaderVersion == document.minimumReaderVersion,
              projectID == document.projectID,
              projectRevision == document.revision else {
            throw ProjectPersistenceError.invalidManifest(
                "Project identity, revision, or schema does not match project.json."
            )
        }
        let actual = DeterministicProjectCodec().checksum(data: projectData)
        guard actual == projectChecksum else {
            throw ProjectPersistenceError.checksumMismatch(
                expected: projectChecksum,
                actual: actual
            )
        }
        let canonical = try DeterministicProjectCodec().encode(document)
        guard canonical == projectData else {
            throw ProjectPersistenceError.invalidManifest(
                "project.json is not the canonical deterministic encoding."
            )
        }
    }
}

public struct VertexProjectManifestCodec: Sendable {
    public init() {}

    public func encode(_ manifest: VertexProjectManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        do {
            return try encoder.encode(manifest)
        } catch {
            throw ProjectPersistenceError.invalidManifest(
                "Manifest encoding failed: \(error.localizedDescription)"
            )
        }
    }

    public func decode(_ data: Data) throws -> VertexProjectManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        do {
            let manifest = try decoder.decode(VertexProjectManifest.self, from: data)
            return try VertexProjectManifest(
                packageFormatVersion: manifest.packageFormatVersion,
                schemaVersion: manifest.schemaVersion,
                minimumReaderVersion: manifest.minimumReaderVersion,
                projectID: manifest.projectID,
                projectRevision: manifest.projectRevision,
                projectChecksum: manifest.projectChecksum,
                createdByAppVersion: manifest.createdByAppVersion,
                lastSavedByAppVersion: manifest.lastSavedByAppVersion,
                lastSuccessfulSave: manifest.lastSuccessfulSave
            )
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.invalidManifest(
                "Manifest decoding failed: \(error.localizedDescription)"
            )
        }
    }
}
