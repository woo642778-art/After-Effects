import Foundation
import VertexProject

public struct LegacySourceTreeDigest: Sendable {
    public init() {}

    public func digest(of sourceURL: URL) throws -> String {
        let root = sourceURL.standardizedFileURL
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "missing legacy source")
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in false }
        ) else {
            throw ProjectPersistenceError.legacyImportIncomplete(stage: "source enumeration")
        }

        var files: [(relativePath: String, url: URL)] = []
        for case let url as URL in enumerator {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: Set(keys))
            } catch {
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "source metadata: \(error.localizedDescription)"
                )
            }
            if values.isSymbolicLink == true {
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "symbolic links are not supported in legacy packages"
                )
            }
            guard values.isRegularFile == true else { continue }
            let relative = relativePath(of: url, under: root)
            files.append((relative, url))
        }
        files.sort { $0.relativePath < $1.relativePath }

        var payload = Data()
        for file in files {
            let pathData = Data(file.relativePath.precomposedStringWithCanonicalMapping.utf8)
            let bytes: Data
            do {
                bytes = try Data(contentsOf: file.url)
            } catch {
                throw ProjectPersistenceError.legacyImportIncomplete(
                    stage: "source bytes: \(error.localizedDescription)"
                )
            }
            appendLength(pathData.count, to: &payload)
            payload.append(pathData)
            appendLength(bytes.count, to: &payload)
            payload.append(bytes)
        }
        return StableProjectSHA256.hexDigest(payload)
    }

    private func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count))
    }

    private func appendLength(_ length: Int, to data: inout Data) {
        var value = UInt64(length).bigEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
}
