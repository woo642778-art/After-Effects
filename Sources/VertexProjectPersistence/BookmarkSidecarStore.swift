import Foundation
import VertexCore

public struct AppleBookmarkAdapter: Sendable {
    private let createImplementation: @Sendable (URL) throws -> Data
    private let resolveImplementation: @Sendable (Data) throws -> (url: URL, isStale: Bool)

    public init() {
        self.createImplementation = { url in
            #if os(macOS)
            do {
                return try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Security-scoped bookmark creation failed: \(error.localizedDescription)"
                )
            }
            #elseif os(iOS)
            do {
                return try url.bookmarkData(
                    options: [.minimalBookmark],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Bookmark creation failed: \(error.localizedDescription)"
                )
            }
            #else
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Apple bookmark APIs are unavailable on this platform."
            )
            #endif
        }
        self.resolveImplementation = { data in
            #if os(macOS)
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (url, isStale)
            } catch {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Security-scoped bookmark resolution failed: \(error.localizedDescription)"
                )
            }
            #elseif os(iOS)
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (url, isStale)
            } catch {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Bookmark resolution failed: \(error.localizedDescription)"
                )
            }
            #else
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Apple bookmark APIs are unavailable on this platform."
            )
            #endif
        }
    }

    package init(
        create: @escaping @Sendable (URL) throws -> Data,
        resolve: @escaping @Sendable (Data) throws -> (url: URL, isStale: Bool)
    ) {
        self.createImplementation = create
        self.resolveImplementation = resolve
    }

    public func create(for url: URL) throws -> Data {
        let data = try createImplementation(url)
        guard !data.isEmpty else {
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "The bookmark adapter returned empty data."
            )
        }
        return data
    }

    public func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        guard !data.isEmpty else {
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "The bookmark sidecar is empty."
            )
        }
        return try resolveImplementation(data)
    }
}

public struct BookmarkSidecarStore: Sendable {
    public init() {}

    public func write(_ data: Data, mediaID: VertexID, in packageURL: URL) throws {
        guard !data.isEmpty else {
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Bookmark data must not be empty."
            )
        }

        let layout = try VertexProjectPackageLayout(root: packageURL)
        try layout.createRequiredDirectories()
        let destinationURL = layout.bookmarkURL(mediaID: mediaID.rawValue)
        let temporaryURL = layout.bookmarkTemporaryURL(mediaID: mediaID.rawValue)
        let io = DurableFileIO()

        do {
            try io.writeAndSynchronize(data, to: temporaryURL)
            let verified = try Data(contentsOf: temporaryURL)
            guard verified == data else {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Temporary bookmark verification failed for \(mediaID.rawValue)."
                )
            }
            try io.atomicPromote(temporaryURL, to: destinationURL)
            try io.synchronizeDirectory(layout.bookmarksDirectoryURL)

            let promoted = try Data(contentsOf: destinationURL)
            guard promoted == data else {
                throw ProjectPersistenceError.bookmarkOperationFailed(
                    "Promoted bookmark verification failed for \(mediaID.rawValue)."
                )
            }
        } catch let error as ProjectPersistenceError {
            try? io.removeIfPresent(temporaryURL)
            throw error
        } catch {
            try? io.removeIfPresent(temporaryURL)
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Bookmark sidecar write failed: \(error.localizedDescription)"
            )
        }
    }

    public func read(mediaID: VertexID, in packageURL: URL) throws -> Data? {
        let layout = try VertexProjectPackageLayout(root: packageURL)
        let url = layout.bookmarkURL(mediaID: mediaID.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Bookmark sidecar could not be read: \(error.localizedDescription)"
            )
        }
    }

    public func remove(mediaID: VertexID, in packageURL: URL) throws {
        let layout = try VertexProjectPackageLayout(root: packageURL)
        let io = DurableFileIO()
        do {
            try io.removeIfPresent(layout.bookmarkTemporaryURL(mediaID: mediaID.rawValue))
            try io.removeIfPresent(layout.bookmarkURL(mediaID: mediaID.rawValue))
            try io.synchronizeDirectory(layout.bookmarksDirectoryURL)
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.bookmarkOperationFailed(
                "Bookmark sidecar could not be removed: \(error.localizedDescription)"
            )
        }
    }

    public func resolveAndRefreshIfNeeded(
        mediaID: VertexID,
        in packageURL: URL,
        adapter: AppleBookmarkAdapter = AppleBookmarkAdapter()
    ) throws -> URL? {
        guard let data = try read(mediaID: mediaID, in: packageURL) else {
            return nil
        }
        let resolved = try adapter.resolve(data)
        if resolved.isStale {
            let refreshed = try adapter.create(for: resolved.url)
            try write(refreshed, mediaID: mediaID, in: packageURL)
        }
        return resolved.url
    }
}
