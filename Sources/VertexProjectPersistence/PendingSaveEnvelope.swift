import Foundation
import VertexProject

public struct VerifiedProjectPair: Equatable, Sendable {
    public let document: ProjectDocument
    public let manifest: VertexProjectManifest
    public let projectData: Data
    public let manifestData: Data

    public init(
        document: ProjectDocument,
        manifest: VertexProjectManifest,
        projectData: Data,
        manifestData: Data
    ) {
        self.document = document
        self.manifest = manifest
        self.projectData = projectData
        self.manifestData = manifestData
    }
}

public struct PendingSaveEnvelope: Codable, Equatable, Sendable {
    public static let currentEnvelopeVersion = 1

    public let envelopeVersion: Int
    public var projectData: Data
    public var manifestData: Data
    public let projectChecksum: String
    public let manifestChecksum: String

    public init(
        envelopeVersion: Int = Self.currentEnvelopeVersion,
        projectData: Data,
        manifestData: Data
    ) {
        self.envelopeVersion = envelopeVersion
        self.projectData = projectData
        self.manifestData = manifestData
        self.projectChecksum = StableProjectSHA256.hexDigest(projectData)
        self.manifestChecksum = StableProjectSHA256.hexDigest(manifestData)
    }

    public func verifiedPair() throws -> VerifiedProjectPair {
        guard envelopeVersion == Self.currentEnvelopeVersion else {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Unsupported envelope version \(envelopeVersion)."
            )
        }

        let actualProjectChecksum = StableProjectSHA256.hexDigest(projectData)
        guard actualProjectChecksum == projectChecksum else {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Project payload checksum mismatch."
            )
        }
        let actualManifestChecksum = StableProjectSHA256.hexDigest(manifestData)
        guard actualManifestChecksum == manifestChecksum else {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Manifest payload checksum mismatch."
            )
        }

        do {
            let document = try DeterministicProjectCodec().decode(projectData)
            let manifest = try VertexProjectManifestCodec().decode(manifestData)
            try manifest.validate(document: document, projectData: projectData)
            return VerifiedProjectPair(
                document: document,
                manifest: manifest,
                projectData: projectData,
                manifestData: manifestData
            )
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Pending pair validation failed: \(error.localizedDescription)"
            )
        }
    }
}

public struct PendingSaveEnvelopeCodec: Sendable {
    public init() {}

    public func encode(_ envelope: PendingSaveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(envelope)
        } catch {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Envelope encoding failed: \(error.localizedDescription)"
            )
        }
    }

    public func decode(_ data: Data) throws -> PendingSaveEnvelope {
        do {
            return try JSONDecoder().decode(PendingSaveEnvelope.self, from: data)
        } catch {
            throw ProjectPersistenceError.pendingSnapshotCorrupt(
                "Envelope decoding failed: \(error.localizedDescription)"
            )
        }
    }
}
