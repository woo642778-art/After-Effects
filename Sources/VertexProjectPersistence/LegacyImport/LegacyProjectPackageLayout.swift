import Foundation
import VertexProject

package struct LegacyProjectPackageLayout: Sendable {
    package let root: URL

    package init(root: URL) throws {
        guard root.isFileURL else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy package must use a file URL")
        }
        self.root = root.standardizedFileURL
    }

    package var projectURL: URL {
        root.appendingPathComponent("project.json", isDirectory: false)
    }

    package var manifestURL: URL {
        root.appendingPathComponent("manifest.json", isDirectory: false)
    }

    package var historyURL: URL {
        root.appendingPathComponent("history.json", isDirectory: false)
    }

    package var journalDirectoryURL: URL {
        root.appendingPathComponent("journal", isDirectory: true)
    }

    package var journalURL: URL {
        journalDirectoryURL.appendingPathComponent("operations.log", isDirectory: false)
    }

    package var autosavesDirectoryURL: URL {
        root.appendingPathComponent("autosaves", isDirectory: true)
    }

    package var mediaDirectoryURL: URL {
        root.appendingPathComponent("media", isDirectory: true)
    }

    package func embeddedMediaURL(relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !trimmed.split(separator: "/", omittingEmptySubsequences: false).contains("..") else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy embedded media path is unsafe")
        }
        let candidate = root.appendingPathComponent(trimmed).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "legacy embedded media escaped package root")
        }
        return candidate
    }
}
