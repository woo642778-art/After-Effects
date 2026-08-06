import Foundation
import VertexProject

public struct ProjectPackageLayout: Equatable, Sendable {
    public let root: URL

    public init(root: URL) throws {
        guard root.isFileURL else {
            throw ProjectError.invalidPackagePath("Project packages must use file URLs.")
        }
        self.root = root.standardizedFileURL
    }

    public var projectURL: URL { root.appendingPathComponent("project.json", isDirectory: false) }
    public var projectTemporaryURL: URL { root.appendingPathComponent("project.json.tmp", isDirectory: false) }
    public var projectBackupURL: URL { root.appendingPathComponent("project.json.backup", isDirectory: false) }
    public var manifestURL: URL { root.appendingPathComponent("manifest.json", isDirectory: false) }
    public var manifestTemporaryURL: URL { root.appendingPathComponent("manifest.json.tmp", isDirectory: false) }
    public var historyURL: URL { root.appendingPathComponent("history.json", isDirectory: false) }
    public var historyTemporaryURL: URL { root.appendingPathComponent("history.json.tmp", isDirectory: false) }

    public var journalDirectoryURL: URL { root.appendingPathComponent("journal", isDirectory: true) }
    public var journalURL: URL { journalDirectoryURL.appendingPathComponent("operations.log", isDirectory: false) }
    public var autosavesDirectoryURL: URL { root.appendingPathComponent("autosaves", isDirectory: true) }
    public var mediaDirectoryURL: URL { root.appendingPathComponent("media", isDirectory: true) }
    public var proxiesDirectoryURL: URL { root.appendingPathComponent("proxies", isDirectory: true) }
    public var thumbnailsDirectoryURL: URL { root.appendingPathComponent("thumbnails", isDirectory: true) }
    public var recoveryDirectoryURL: URL { root.appendingPathComponent("recovery", isDirectory: true) }
    public var quarantineDirectoryURL: URL { recoveryDirectoryURL.appendingPathComponent("quarantine", isDirectory: true) }

    public var autosaveCurrentURL: URL { autosavesDirectoryURL.appendingPathComponent("snapshot-current.json") }
    public var autosavePreviousURL: URL { autosavesDirectoryURL.appendingPathComponent("snapshot-previous.json") }

    public func embeddedMediaURL(relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !trimmed.split(separator: "/", omittingEmptySubsequences: false).contains("..") else {
            throw ProjectError.invalidPackagePath("Package-relative media paths cannot be absolute or contain parent traversal.")
        }
        let candidate = root.appendingPathComponent(trimmed).standardizedFileURL
        let rootPath = root.standardizedFileURL.path.hasSuffix("/") ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw ProjectError.invalidPackagePath("Package-relative media path escaped the project package.")
        }
        return candidate
    }

    public func createDirectories(fileManager: FileManager = .default) throws {
        let directories = [
            root,
            journalDirectoryURL,
            autosavesDirectoryURL,
            mediaDirectoryURL,
            proxiesDirectoryURL,
            thumbnailsDirectoryURL,
            recoveryDirectoryURL,
            quarantineDirectoryURL
        ]
        do {
            for directory in directories {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        } catch {
            throw ProjectError.packageCorruption("Project package directories could not be created: \(error.localizedDescription)")
        }
    }
}
