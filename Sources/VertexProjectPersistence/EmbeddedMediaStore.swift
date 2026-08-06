import Foundation
import VertexProject

public struct EmbeddedMediaStore: Sendable {
    public init() {}

    public func fingerprint(of url: URL) throws -> String {
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return StableProjectSHA256.hexDigest(data)
        } catch {
            throw ProjectPersistenceError.embeddedMediaMismatch(
                mediaID(from: url) ?? fallbackMediaID
            )
        }
    }

    public func embed(
        reference: MediaReference,
        sourceURL: URL,
        packageURL: URL
    ) throws -> MediaReference {
        let validatedReference: MediaReference
        do {
            validatedReference = try reference.validated()
        } catch {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }

        let fileManager = FileManager.default
        guard sourceURL.isFileURL,
              fileManager.fileExists(atPath: sourceURL.path) else {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        } catch {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }
        let actualFingerprint = StableProjectSHA256.hexDigest(sourceData)
        if let expected = validatedReference.contentFingerprint,
           expected.lowercased() != actualFingerprint {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }

        let layout = try VertexProjectPackageLayout(root: packageURL)
        try layout.createRequiredDirectories()
        let filename = "\(reference.id.rawValue)-\(sanitizedFilename(reference.originalFilename))"
        let destinationURL = try layout.embeddedMediaURL(filename: filename)
        let temporaryURL = try layout.embeddedMediaTemporaryURL(filename: filename)
        let io = DurableFileIO()

        if fileManager.fileExists(atPath: destinationURL.path) {
            guard try verifiedFingerprint(of: destinationURL, mediaID: reference.id) == actualFingerprint else {
                throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
            }
        } else {
            do {
                try io.writeAndSynchronize(sourceData, to: temporaryURL)
                guard try verifiedFingerprint(of: temporaryURL, mediaID: reference.id) == actualFingerprint else {
                    throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
                }
                try io.atomicPromote(temporaryURL, to: destinationURL)
                try io.synchronizeDirectory(layout.mediaDirectoryURL)
            } catch let error as ProjectPersistenceError {
                try? io.removeIfPresent(temporaryURL)
                throw error
            } catch {
                try? io.removeIfPresent(temporaryURL)
                throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
            }
        }

        guard try verifiedFingerprint(of: destinationURL, mediaID: reference.id) == actualFingerprint else {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }

        var embedded = validatedReference
        embedded.fileSize = Int64(sourceData.count)
        embedded.contentFingerprint = actualFingerprint
        embedded.locator.embeddedPath = "Media/\(filename)"
        embedded.availabilityStatus = .embedded
        do {
            return try embedded.validated()
        } catch {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }
    }

    public func resolve(
        reference: MediaReference,
        packageURL: URL
    ) throws -> URL? {
        guard let relativePath = reference.locator.embeddedPath else { return nil }
        guard relativePath.hasPrefix("Media/") else {
            throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
        }
        let filename = String(relativePath.dropFirst("Media/".count))
        let layout = try VertexProjectPackageLayout(root: packageURL)
        let url = try layout.embeddedMediaURL(filename: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if let expected = reference.contentFingerprint {
            let actual = try verifiedFingerprint(of: url, mediaID: reference.id)
            guard actual == expected.lowercased() else {
                throw ProjectPersistenceError.embeddedMediaMismatch(reference.id)
            }
        }
        return url
    }

    private func verifiedFingerprint(of url: URL, mediaID: VertexID) throws -> String {
        do {
            return StableProjectSHA256.hexDigest(
                try Data(contentsOf: url, options: [.mappedIfSafe])
            )
        } catch {
            throw ProjectPersistenceError.embeddedMediaMismatch(mediaID)
        }
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        var result = String(filename.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(String(scalar)) : "_"
        })
        while result.contains("..") {
            result = result.replacingOccurrences(of: "..", with: "_")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        result = String(result.prefix(120))
        return result.isEmpty ? "media.bin" : result
    }

    private var fallbackMediaID: VertexID {
        VertexID(rawValue: "00000000-0000-0000-0000-000000000000")
    }

    private func mediaID(from url: URL) -> VertexID? {
        let token = url.lastPathComponent.split(separator: "-").prefix(5).joined(separator: "-")
        return try? VertexID(parsing: token)
    }
}
