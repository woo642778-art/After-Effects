import Foundation

public enum PackageValidationMode: Equatable, Sendable {
    case steadyState
    case transactionRecovery
}

public struct VertexProjectPackageLayout: Equatable, Sendable {
    public static let requiredExtension = "vertexproject"
    public static let requiredDirectories = ["Journal", "Autosaves", "Bookmarks", "Media"]
    public static let steadyStateRootEntries = Set([
        "project.json", "manifest.json", "Journal", "Autosaves", "Bookmarks", "Media"
    ])

    public let root: URL

    public init(root: URL) throws {
        guard root.isFileURL else {
            throw ProjectPersistenceError.unsupportedPackageExtension(found: root.pathExtension)
        }
        let found = root.pathExtension.lowercased()
        guard found == Self.requiredExtension else {
            throw ProjectPersistenceError.unsupportedPackageExtension(found: found)
        }
        self.root = root.standardizedFileURL
    }

    public var projectURL: URL { root.appendingPathComponent("project.json") }
    public var manifestURL: URL { root.appendingPathComponent("manifest.json") }
    public var projectTemporaryURL: URL { root.appendingPathComponent("project.json.tmp") }
    public var manifestTemporaryURL: URL { root.appendingPathComponent("manifest.json.tmp") }

    public var journalDirectoryURL: URL { root.appendingPathComponent("Journal", isDirectory: true) }
    public var autosavesDirectoryURL: URL { root.appendingPathComponent("Autosaves", isDirectory: true) }
    public var bookmarksDirectoryURL: URL { root.appendingPathComponent("Bookmarks", isDirectory: true) }
    public var mediaDirectoryURL: URL { root.appendingPathComponent("Media", isDirectory: true) }

    public var pendingSaveURL: URL { journalDirectoryURL.appendingPathComponent("pending-save.json") }
    public var pendingSaveTemporaryURL: URL { journalDirectoryURL.appendingPathComponent("pending-save.json.tmp") }

    public func bookmarkURL(mediaID: String) -> URL {
        bookmarksDirectoryURL.appendingPathComponent("\(mediaID.lowercased()).bookmark")
    }

    public func bookmarkTemporaryURL(mediaID: String) -> URL {
        bookmarksDirectoryURL.appendingPathComponent("\(mediaID.lowercased()).bookmark.tmp")
    }

    public func createRequiredDirectories(fileManager: FileManager = .default) throws {
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            for name in Self.requiredDirectories {
                try fileManager.createDirectory(
                    at: root.appendingPathComponent(name, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
        } catch {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Required package directories could not be created: \(error.localizedDescription)"
            )
        }
    }

    public func validateAllowlist(
        fileManager: FileManager = .default,
        mode: PackageValidationMode
    ) throws {
        guard fileManager.fileExists(atPath: root.path) else {
            throw ProjectPersistenceError.forbiddenPackageEntry("missing package root")
        }

        let rootEntries = try entries(in: root, fileManager: fileManager)
        let allowedRoot = Self.steadyStateRootEntries.union(
            mode == .transactionRecovery ? ["project.json.tmp", "manifest.json.tmp"] : []
        )
        for entry in rootEntries where !allowedRoot.contains(entry) {
            throw ProjectPersistenceError.forbiddenPackageEntry(entry)
        }

        for directory in Self.requiredDirectories where !rootEntries.contains(directory) {
            throw ProjectPersistenceError.forbiddenPackageEntry("missing \(directory)")
        }

        try validateJournal(mode: mode, fileManager: fileManager)
        try validateAutosaves(mode: mode, fileManager: fileManager)
        try validateBookmarks(mode: mode, fileManager: fileManager)
        try validateMedia(mode: mode, fileManager: fileManager)
    }

    private func validateJournal(mode: PackageValidationMode, fileManager: FileManager) throws {
        let allowed = mode == .transactionRecovery
            ? Set(["pending-save.json", "pending-save.json.tmp"])
            : Set<String>()
        for entry in try entries(in: journalDirectoryURL, fileManager: fileManager) where !allowed.contains(entry) {
            throw ProjectPersistenceError.forbiddenPackageEntry("Journal/\(entry)")
        }
    }

    private func validateAutosaves(mode: PackageValidationMode, fileManager: FileManager) throws {
        for entry in try entries(in: autosavesDirectoryURL, fileManager: fileManager) {
            let canonical = matches(entry, pattern: #"^[0-9]{20}-[0-9a-f]{64}\.json$"#)
            let temporary = mode == .transactionRecovery
                && matches(entry, pattern: #"^[0-9]{20}-[0-9a-f]{64}\.json\.tmp$"#)
            guard canonical || temporary else {
                throw ProjectPersistenceError.forbiddenPackageEntry("Autosaves/\(entry)")
            }
        }
    }

    private func validateBookmarks(mode: PackageValidationMode, fileManager: FileManager) throws {
        let uuid = #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#
        for entry in try entries(in: bookmarksDirectoryURL, fileManager: fileManager) {
            let canonical = matches(entry, pattern: "^\(uuid)\\.bookmark$")
            let temporary = mode == .transactionRecovery
                && matches(entry, pattern: "^\(uuid)\\.bookmark\\.tmp$")
            guard canonical || temporary else {
                throw ProjectPersistenceError.forbiddenPackageEntry("Bookmarks/\(entry)")
            }
        }
    }

    private func validateMedia(mode: PackageValidationMode, fileManager: FileManager) throws {
        for entry in try entries(in: mediaDirectoryURL, fileManager: fileManager) {
            guard !entry.isEmpty, !entry.hasPrefix("."), !entry.contains("/") else {
                throw ProjectPersistenceError.forbiddenPackageEntry("Media/\(entry)")
            }
            if entry.hasSuffix(".tmp"), mode != .transactionRecovery {
                throw ProjectPersistenceError.forbiddenPackageEntry("Media/\(entry)")
            }
        }
    }

    private func entries(in directory: URL, fileManager: FileManager) throws -> Set<String> {
        do {
            return Set(try fileManager.contentsOfDirectory(atPath: directory.path))
        } catch {
            throw ProjectPersistenceError.forbiddenPackageEntry(
                "unreadable \(directory.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    private func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
