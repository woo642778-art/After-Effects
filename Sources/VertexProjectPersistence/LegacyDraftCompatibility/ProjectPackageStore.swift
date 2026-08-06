import Foundation
import VertexProject

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum ProjectStoreFailurePoint: String, Sendable {
    case afterTemporaryProjectWrite
}

public struct ProjectPackageLoadResult: Sendable {
    public var layout: ProjectPackageLayout
    public var document: ProjectDocument
    public var manifest: ProjectManifest
    public var history: ProjectHistorySnapshot
    public var journalAnalysis: ProjectJournalAnalysis

    public init(
        layout: ProjectPackageLayout,
        document: ProjectDocument,
        manifest: ProjectManifest,
        history: ProjectHistorySnapshot,
        journalAnalysis: ProjectJournalAnalysis
    ) {
        self.layout = layout
        self.document = document
        self.manifest = manifest
        self.history = history
        self.journalAnalysis = journalAnalysis
    }
}

public struct ProjectPackageStore {
    private let fileManager: FileManager
    private let projectCodec: DeterministicProjectCodec
    private let journalCodec: ProjectJournalCodec
    private let failurePoint: ProjectStoreFailurePoint?

    public init(
        fileManager: FileManager = .default,
        failurePoint: ProjectStoreFailurePoint? = nil
    ) {
        self.fileManager = fileManager
        self.projectCodec = DeterministicProjectCodec()
        self.journalCodec = ProjectJournalCodec()
        self.failurePoint = failurePoint
    }

    @discardableResult
    public func create(
        at packageURL: URL,
        document: ProjectDocument,
        history: ProjectHistorySnapshot = ProjectHistorySnapshot()
    ) throws -> ProjectPackageLoadResult {
        let layout = try ProjectPackageLayout(root: packageURL)
        if fileManager.fileExists(atPath: layout.projectURL.path) || fileManager.fileExists(atPath: layout.manifestURL.path) {
            throw ProjectError.packageCorruption("A project package already exists at the selected location.")
        }
        try layout.createDirectories(fileManager: fileManager)
        if !fileManager.fileExists(atPath: layout.journalURL.path) {
            guard fileManager.createFile(atPath: layout.journalURL.path, contents: Data()) else {
                throw ProjectError.packageCorruption("The project journal could not be created.")
            }
        }
        return try save(
            document,
            history: history,
            to: packageURL,
            committedJournalSequence: 0
        )
    }

    @discardableResult
    public func save(
        _ document: ProjectDocument,
        history: ProjectHistorySnapshot = ProjectHistorySnapshot(),
        to packageURL: URL,
        committedJournalSequence: UInt64
    ) throws -> ProjectPackageLoadResult {
        let layout = try ProjectPackageLayout(root: packageURL)
        try layout.createDirectories(fileManager: fileManager)

        let validatedDocument = try document.validated()
        let projectData = try projectCodec.encode(validatedDocument)
        let decodedProject = try projectCodec.decode(projectData)
        guard try projectCodec.encode(decodedProject) == projectData else {
            throw ProjectError.deterministicEncodingFailure("The project did not produce identical canonical bytes after decode and re-encode.")
        }
        let checksum = projectCodec.checksum(data: projectData)
        let historyData = try encodeHistory(history)
        _ = try decodeHistory(historyData)
        let manifest = ProjectManifest(
            document: decodedProject,
            projectChecksum: checksum,
            committedJournalSequence: committedJournalSequence,
            lastSuccessfulSave: decodedProject.metadata.modifiedAt,
            integrityStatus: .valid
        )
        let manifestData = try encodeManifest(manifest)
        _ = try decodeManifest(manifestData)

        try writeDurably(projectData, to: layout.projectTemporaryURL)
        if failurePoint == .afterTemporaryProjectWrite {
            throw ProjectError.atomicReplacementFailure("Injected failure after the temporary project write.")
        }
        try writeDurably(historyData, to: layout.historyTemporaryURL)
        try writeDurably(manifestData, to: layout.manifestTemporaryURL)

        if fileManager.fileExists(atPath: layout.projectURL.path) {
            try replaceBackup(at: layout.projectBackupURL, withCopyOf: layout.projectURL)
        }
        try atomicPromote(layout.projectTemporaryURL, to: layout.projectURL)
        try atomicPromote(layout.historyTemporaryURL, to: layout.historyURL)
        try atomicPromote(layout.manifestTemporaryURL, to: layout.manifestURL)

        if !fileManager.fileExists(atPath: layout.journalURL.path) {
            guard fileManager.createFile(atPath: layout.journalURL.path, contents: Data()) else {
                throw ProjectError.packageCorruption("The project journal could not be created.")
            }
        }
        return try load(from: packageURL)
    }

    public func load(from packageURL: URL) throws -> ProjectPackageLoadResult {
        let layout = try ProjectPackageLayout(root: packageURL)
        guard fileManager.fileExists(atPath: layout.projectURL.path),
              fileManager.fileExists(atPath: layout.manifestURL.path) else {
            throw ProjectError.packageCorruption("The project package is missing project.json or manifest.json.")
        }

        let projectData: Data
        let manifestData: Data
        do {
            projectData = try Data(contentsOf: layout.projectURL)
            manifestData = try Data(contentsOf: layout.manifestURL)
        } catch {
            throw ProjectError.packageCorruption("Project package files could not be read: \(error.localizedDescription)")
        }

        let document = try projectCodec.decode(projectData)
        let manifest = try decodeManifest(manifestData)
        let actualChecksum = projectCodec.checksum(data: projectData)
        guard manifest.projectChecksum == actualChecksum else {
            throw ProjectError.checksumMismatch(expected: manifest.projectChecksum, actual: actualChecksum)
        }
        guard manifest.projectID == document.projectID,
              manifest.projectRevision == document.revision,
              manifest.schemaVersion == document.schemaVersion else {
            throw ProjectError.manifestCorruption("Manifest identity, revision, or schema does not match project.json.")
        }

        let history: ProjectHistorySnapshot
        if fileManager.fileExists(atPath: layout.historyURL.path) {
            do {
                history = try decodeHistory(Data(contentsOf: layout.historyURL))
            } catch let error as ProjectError {
                throw error
            } catch {
                throw ProjectError.packageCorruption("Project history could not be read: \(error.localizedDescription)")
            }
        } else {
            history = ProjectHistorySnapshot()
        }

        let journalData = (try? Data(contentsOf: layout.journalURL)) ?? Data()
        let journalAnalysis = try journalCodec.analyze(journalData)
        return ProjectPackageLoadResult(
            layout: layout,
            document: document,
            manifest: manifest,
            history: history,
            journalAnalysis: journalAnalysis
        )
    }

    public func appendJournal(_ record: ProjectJournalRecord, to packageURL: URL) throws {
        let layout = try ProjectPackageLayout(root: packageURL)
        try layout.createDirectories(fileManager: fileManager)
        if !fileManager.fileExists(atPath: layout.journalURL.path) {
            guard fileManager.createFile(atPath: layout.journalURL.path, contents: Data()) else {
                throw ProjectError.packageCorruption("The project journal could not be created.")
            }
        }
        let data = try journalCodec.encodeLine(record)
        do {
            let handle = try FileHandle(forWritingTo: layout.journalURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            throw ProjectError.journalCorruption("The journal record could not be durably appended: \(error.localizedDescription)")
        }
    }

    internal func encodeManifest(_ manifest: ProjectManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        do {
            return try encoder.encode(manifest)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Manifest could not be encoded: \(error.localizedDescription)")
        }
    }

    internal func decodeManifest(_ data: Data) throws -> ProjectManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        do {
            return try decoder.decode(ProjectManifest.self, from: data)
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.manifestCorruption("Manifest could not be decoded: \(error.localizedDescription)")
        }
    }

    internal func encodeHistory(_ history: ProjectHistorySnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(history)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Project history could not be encoded: \(error.localizedDescription)")
        }
    }

    internal func decodeHistory(_ data: Data) throws -> ProjectHistorySnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            return try decoder.decode(ProjectHistorySnapshot.self, from: data)
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Project history could not be decoded: \(error.localizedDescription)")
        }
    }

    internal func writeDurably(_ data: Data, to url: URL) throws {
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            guard fileManager.createFile(atPath: url.path, contents: nil) else {
                throw ProjectError.atomicReplacementFailure("Temporary file could not be created at \(url.lastPathComponent).")
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.atomicReplacementFailure("Temporary file could not be durably written: \(error.localizedDescription)")
        }
    }

    internal func atomicPromote(_ source: URL, to destination: URL) throws {
        let result: Int32 = source.path.withCString { sourcePath in
            destination.path.withCString { destinationPath in
                #if canImport(Darwin)
                Darwin.rename(sourcePath, destinationPath)
                #elseif canImport(Glibc)
                Glibc.rename(sourcePath, destinationPath)
                #else
                -1
                #endif
            }
        }
        guard result == 0 else {
            throw ProjectError.atomicReplacementFailure("Atomic rename failed for \(destination.lastPathComponent).")
        }
    }

    private func replaceBackup(at backupURL: URL, withCopyOf sourceURL: URL) throws {
        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: sourceURL, to: backupURL)
        } catch {
            throw ProjectError.atomicReplacementFailure("The previous valid project could not be preserved as a backup: \(error.localizedDescription)")
        }
    }
}
