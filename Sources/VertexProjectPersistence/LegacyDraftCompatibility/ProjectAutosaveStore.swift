import Foundation
import VertexProject

public struct ProjectAutosaveSnapshot: Codable, Equatable, Sendable {
    public var document: ProjectDocument
    public var history: ProjectHistorySnapshot
    public var createdAt: Date

    public init(document: ProjectDocument, history: ProjectHistorySnapshot, createdAt: Date) {
        self.document = document
        self.history = history
        self.createdAt = createdAt
    }
}

public struct ProjectAutosaveStore {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func rotate(
        document: ProjectDocument,
        history: ProjectHistorySnapshot,
        in packageURL: URL,
        timestamp: Date = Date()
    ) throws {
        let layout = try ProjectPackageLayout(root: packageURL)
        try layout.createDirectories(fileManager: fileManager)
        let snapshot = ProjectAutosaveSnapshot(
            document: try document.validated(),
            history: history,
            createdAt: timestamp
        )
        let data = try encode(snapshot)
        let store = ProjectPackageStore(fileManager: fileManager)

        do {
            if fileManager.fileExists(atPath: layout.autosaveCurrentURL.path) {
                if fileManager.fileExists(atPath: layout.autosavePreviousURL.path) {
                    try fileManager.removeItem(at: layout.autosavePreviousURL)
                }
                try fileManager.copyItem(at: layout.autosaveCurrentURL, to: layout.autosavePreviousURL)
            }

            let currentTemporary = layout.autosavesDirectoryURL.appendingPathComponent("snapshot-current.json.tmp")
            try store.writeDurably(data, to: currentTemporary)
            try store.atomicPromote(currentTemporary, to: layout.autosaveCurrentURL)

            let seconds = Int64(timestamp.timeIntervalSince1970.rounded(.down))
            let hourlyURL = layout.autosavesDirectoryURL.appendingPathComponent("snapshot-hourly-\(seconds).json")
            let hourlyTemporary = layout.autosavesDirectoryURL.appendingPathComponent("snapshot-hourly-\(seconds).json.tmp")
            try store.writeDurably(data, to: hourlyTemporary)
            try store.atomicPromote(hourlyTemporary, to: hourlyURL)
            try trimHourlySnapshots(layout: layout)
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.autosaveRotationFailure("Autosave rotation failed: \(error.localizedDescription)")
        }
    }

    public func snapshotURLs(in packageURL: URL) throws -> [URL] {
        let layout = try ProjectPackageLayout(root: packageURL)
        guard fileManager.fileExists(atPath: layout.autosavesDirectoryURL.path) else { return [] }
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: layout.autosavesDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ProjectError.autosaveRotationFailure("Autosave directory could not be read: \(error.localizedDescription)")
        }
        return contents
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".tmp") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func loadSnapshot(at url: URL) throws -> ProjectAutosaveSnapshot {
        do {
            return try decode(Data(contentsOf: url))
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.packageCorruption("Autosave snapshot could not be read: \(error.localizedDescription)")
        }
    }

    private func trimHourlySnapshots(layout: ProjectPackageLayout) throws {
        let hourly = try fileManager.contentsOfDirectory(
            at: layout.autosavesDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("snapshot-hourly-") && $0.pathExtension == "json" }
        .sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if left == right { return $0.lastPathComponent > $1.lastPathComponent }
            return left > right
        }

        for url in hourly.dropFirst(2) {
            try fileManager.removeItem(at: url)
        }
    }

    private func encode(_ snapshot: ProjectAutosaveSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Autosave snapshot could not be encoded: \(error.localizedDescription)")
        }
    }

    private func decode(_ data: Data) throws -> ProjectAutosaveSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let snapshot = try decoder.decode(ProjectAutosaveSnapshot.self, from: data)
            _ = try snapshot.document.validated()
            return snapshot
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Autosave snapshot could not be decoded: \(error.localizedDescription)")
        }
    }
}
