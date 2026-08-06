import Foundation
import VertexProject

public struct ImmutableAutosaveRecord: Equatable, Sendable {
    public let sequence: UInt64
    public let checksum: String
    public let revision: UInt64
    public let createdAt: Date
    public let url: URL
    public let document: ProjectDocument

    public init(
        sequence: UInt64,
        checksum: String,
        revision: UInt64,
        createdAt: Date,
        url: URL,
        document: ProjectDocument
    ) {
        self.sequence = sequence
        self.checksum = checksum
        self.revision = revision
        self.createdAt = createdAt
        self.url = url
        self.document = document
    }
}

private struct ImmutableAutosaveEnvelope: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let sequence: UInt64
    let checksum: String
    let revision: UInt64
    let createdAt: Date
    let document: ProjectDocument

    init(
        formatVersion: Int = Self.currentFormatVersion,
        sequence: UInt64,
        checksum: String,
        revision: UInt64,
        createdAt: Date,
        document: ProjectDocument
    ) {
        self.formatVersion = formatVersion
        self.sequence = sequence
        self.checksum = checksum
        self.revision = revision
        self.createdAt = createdAt
        self.document = document
    }
}

public struct ImmutableAutosaveStore: Sendable {
    private static let retentionLimit = 8
    private static let filenamePattern = #"^([0-9]{20})-([0-9a-f]{64})\.json$"#

    public init() {}

    @discardableResult
    public func write(
        document: ProjectDocument,
        in packageURL: URL,
        createdAt: Date = Date()
    ) throws -> ImmutableAutosaveRecord? {
        let layout = try VertexProjectPackageLayout(root: packageURL)
        try layout.createRequiredDirectories()

        let validated = try document.validated()
        let projectData = try DeterministicProjectCodec().encode(validated)
        let checksum = DeterministicProjectCodec().checksum(data: projectData)
        let existingValid = try validRecords(in: packageURL)

        if existingValid.contains(where: {
            $0.revision == validated.revision && $0.checksum == checksum
        }) {
            return nil
        }

        let sequence = try nextSequence(in: layout.autosavesDirectoryURL)
        let envelope = ImmutableAutosaveEnvelope(
            sequence: sequence,
            checksum: checksum,
            revision: validated.revision,
            createdAt: createdAt,
            document: validated
        )
        let data = try encode(envelope)
        let filename = canonicalFilename(sequence: sequence, checksum: checksum)
        let destinationURL = layout.autosavesDirectoryURL.appendingPathComponent(filename)
        let temporaryURL = destinationURL.appendingPathExtension("tmp")
        let fileManager = FileManager.default

        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Refusing to overwrite existing immutable autosave \(filename)."
            )
        }

        let io = DurableFileIO()
        do {
            try io.writeAndSynchronize(data, to: temporaryURL)
            _ = try decodeRecord(at: temporaryURL, expectedFilename: filename)
            try io.atomicPromote(temporaryURL, to: destinationURL)
            try io.synchronizeDirectory(layout.autosavesDirectoryURL)

            let record = try decodeRecord(at: destinationURL, expectedFilename: filename)
            try trimVerifiedRecords(in: packageURL, preserving: record.url)
            return record
        } catch let error as ProjectPersistenceError {
            try? io.removeIfPresent(temporaryURL)
            throw error
        } catch {
            try? io.removeIfPresent(temporaryURL)
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave write failed: \(error.localizedDescription)"
            )
        }
    }

    public func validRecords(in packageURL: URL) throws -> [ImmutableAutosaveRecord] {
        let layout = try VertexProjectPackageLayout(root: packageURL)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: layout.autosavesDirectoryURL.path) else {
            return []
        }

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: layout.autosavesDirectoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave directory could not be read: \(error.localizedDescription)"
            )
        }

        return urls.compactMap { url in
            guard parseFilename(url.lastPathComponent) != nil else { return nil }
            return try? decodeRecord(at: url, expectedFilename: url.lastPathComponent)
        }
        .sorted { left, right in
            if left.sequence == right.sequence {
                return left.url.lastPathComponent < right.url.lastPathComponent
            }
            return left.sequence < right.sequence
        }
    }

    public func latestValid(in packageURL: URL) throws -> ImmutableAutosaveRecord? {
        try validRecords(in: packageURL).last
    }

    private func trimVerifiedRecords(in packageURL: URL, preserving newURL: URL) throws {
        let records = try validRecords(in: packageURL)
        guard records.count > Self.retentionLimit else { return }

        let removable = records.prefix(records.count - Self.retentionLimit)
        let fileManager = FileManager.default
        do {
            for record in removable where record.url != newURL {
                try fileManager.removeItem(at: record.url)
            }
            let layout = try VertexProjectPackageLayout(root: packageURL)
            try DurableFileIO().synchronizeDirectory(layout.autosavesDirectoryURL)
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Old verified autosaves could not be trimmed: \(error.localizedDescription)"
            )
        }
    }

    private func nextSequence(in directoryURL: URL) throws -> UInt64 {
        let fileManager = FileManager.default
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave sequence could not be inspected: \(error.localizedDescription)"
            )
        }

        let maximum = names.compactMap { parseFilename($0)?.sequence }.max() ?? 0
        guard maximum < UInt64.max else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave sequence is exhausted."
            )
        }
        return maximum + 1
    }

    private func decodeRecord(at url: URL, expectedFilename: String) throws -> ImmutableAutosaveRecord {
        guard let filename = parseFilename(expectedFilename) else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave filename is not canonical: \(expectedFilename)."
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave bytes could not be read: \(error.localizedDescription)"
            )
        }

        let envelope = try decode(data)
        guard envelope.formatVersion == ImmutableAutosaveEnvelope.currentFormatVersion,
              envelope.sequence == filename.sequence,
              envelope.checksum == filename.checksum,
              envelope.revision == envelope.document.revision else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave metadata does not match its filename or document."
            )
        }

        let validated = try envelope.document.validated()
        let projectData = try DeterministicProjectCodec().encode(validated)
        let actualChecksum = DeterministicProjectCodec().checksum(data: projectData)
        guard actualChecksum == envelope.checksum else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave project checksum does not match canonical project bytes."
            )
        }
        guard try encode(envelope) == data else {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave JSON is not canonical deterministic encoding."
            )
        }

        return ImmutableAutosaveRecord(
            sequence: envelope.sequence,
            checksum: envelope.checksum,
            revision: envelope.revision,
            createdAt: envelope.createdAt,
            url: url,
            document: validated
        )
    }

    private func encode(_ envelope: ImmutableAutosaveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        do {
            return try encoder.encode(envelope)
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave encoding failed: \(error.localizedDescription)"
            )
        }
    }

    private func decode(_ data: Data) throws -> ImmutableAutosaveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        do {
            return try decoder.decode(ImmutableAutosaveEnvelope.self, from: data)
        } catch {
            throw ProjectPersistenceError.autosaveVerificationFailed(
                "Autosave decoding failed: \(error.localizedDescription)"
            )
        }
    }

    private func canonicalFilename(sequence: UInt64, checksum: String) -> String {
        String(format: "%020llu-%@.json", sequence, checksum)
    }

    private func parseFilename(_ filename: String) -> (sequence: UInt64, checksum: String)? {
        guard filename.range(of: Self.filenamePattern, options: .regularExpression) != nil else {
            return nil
        }
        let stem = String(filename.dropLast(5))
        guard let separator = stem.firstIndex(of: "-") else { return nil }
        let sequenceToken = String(stem[..<separator])
        let checksum = String(stem[stem.index(after: separator)...])
        guard let sequence = UInt64(sequenceToken) else { return nil }
        return (sequence, checksum)
    }
}
