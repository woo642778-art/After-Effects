import Foundation
import VertexProject

public struct ProjectMediaStore {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func fingerprint(of url: URL) throws -> String {
        do {
            return StableProjectSHA256.hexDigest(try Data(contentsOf: url, options: [.mappedIfSafe]))
        } catch {
            throw ProjectError.missingMedia("Media fingerprint could not be read: \(error.localizedDescription)")
        }
    }

    public func embed(
        reference: MediaReference,
        sourceURL: URL,
        packageURL: URL
    ) throws -> MediaReference {
        _ = try reference.validated()
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ProjectError.missingMedia("The selected external media file no longer exists.")
        }

        let actualFingerprint = try fingerprint(of: sourceURL)
        if let expected = reference.contentFingerprint,
           expected.lowercased() != actualFingerprint.lowercased() {
            throw ProjectError.relinkMismatch("The selected media content fingerprint does not match the project reference.")
        }

        let layout = try ProjectPackageLayout(root: packageURL)
        try layout.createDirectories(fileManager: fileManager)
        let safeName = sanitizedFilename(reference.originalFilename)
        let relativePath = "media/\(reference.id.rawValue)-\(safeName)"
        let destination = try layout.embeddedMediaURL(relativePath: relativePath)

        do {
            if fileManager.fileExists(atPath: destination.path) {
                let existingFingerprint = try fingerprint(of: destination)
                guard existingFingerprint == actualFingerprint else {
                    throw ProjectError.embeddingFailure("An embedded media collision contained different bytes.")
                }
            } else {
                try fileManager.copyItem(at: sourceURL, to: destination)
            }
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.embeddingFailure("Media could not be copied into the project package: \(error.localizedDescription)")
        }

        guard try fingerprint(of: destination) == actualFingerprint else {
            throw ProjectError.embeddingFailure("Embedded media failed post-copy fingerprint verification.")
        }

        var embedded = reference
        embedded.contentFingerprint = actualFingerprint
        embedded.locator.embeddedPath = relativePath
        embedded.availabilityStatus = .embedded
        return try embedded.validated()
    }

    public func resolveEmbedded(
        reference: MediaReference,
        packageURL: URL
    ) throws -> URL? {
        guard let embeddedPath = reference.locator.embeddedPath else { return nil }
        let layout = try ProjectPackageLayout(root: packageURL)
        let url = try layout.embeddedMediaURL(relativePath: embeddedPath)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        if let expected = reference.contentFingerprint {
            let actual = try fingerprint(of: url)
            guard actual.lowercased() == expected.lowercased() else {
                throw ProjectError.checksumMismatch(expected: expected, actual: actual)
            }
        }
        return url
    }

    public func createSecurityScopedBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #elseif os(iOS)
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #else
        throw ProjectError.bookmarkFailure("Security-scoped bookmarks are unavailable on this platform.")
        #endif

        #if os(iOS) || os(macOS)
        do {
            return try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ProjectError.bookmarkFailure("Security-scoped bookmark creation failed: \(error.localizedDescription)")
        }
        #endif
    }

    public func resolveSecurityScopedBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
        #elseif os(iOS)
        let options: URL.BookmarkResolutionOptions = [.withoutUI]
        #else
        throw ProjectError.bookmarkFailure("Security-scoped bookmarks are unavailable on this platform.")
        #endif

        #if os(iOS) || os(macOS)
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw ProjectError.bookmarkFailure("Security-scoped bookmark resolution failed: \(error.localizedDescription)")
        }
        #endif
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = filename.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        let result = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return result.isEmpty ? "media.bin" : String(result.prefix(120))
    }
}
