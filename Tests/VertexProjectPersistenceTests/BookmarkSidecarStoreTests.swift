import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private let bookmarkMediaID = VertexID(rawValue: "54000000-0000-0000-0000-000000000001")

private func bookmarkPackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

private func createBookmarkPackage(_ url: URL, media: MediaReference? = nil) throws {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "54000000-0000-0000-0000-000000000099"),
        name: "Bookmark",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    if let media {
        document.mediaRegistry = [media]
        document.selectedMediaID = media.id
    }
    _ = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_001)
    ).create(at: url, document: document)
}

@Test("Bookmark sidecars use lowercase media IDs and replace bytes atomically")
func bookmarkSidecarsAreAtomic() throws {
    let url = bookmarkPackageURL("AtomicBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    try createBookmarkPackage(url)

    let store = BookmarkSidecarStore()
    try store.write(Data("first".utf8), mediaID: bookmarkMediaID, in: url)
    let layout = try VertexProjectPackageLayout(root: url)
    let sidecarURL = layout.bookmarkURL(mediaID: bookmarkMediaID.rawValue)
    let temporaryURL = layout.bookmarkTemporaryURL(mediaID: bookmarkMediaID.rawValue)

    #expect(sidecarURL.lastPathComponent == "54000000-0000-0000-0000-000000000001.bookmark")
    #expect(try store.read(mediaID: bookmarkMediaID, in: url) == Data("first".utf8))

    try store.write(Data("second".utf8), mediaID: bookmarkMediaID, in: url)
    #expect(try store.read(mediaID: bookmarkMediaID, in: url) == Data("second".utf8))
    #expect(!FileManager.default.fileExists(atPath: temporaryURL.path))
}

@Test("Missing bookmark sidecars do not prevent project opening")
func missingBookmarkIsIsolated() throws {
    let url = bookmarkPackageURL("MissingBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    let media = MediaReference(
        id: bookmarkMediaID,
        displayName: "external.mov",
        originalFilename: "external.mov",
        fileSize: 10,
        modificationDate: nil,
        contentFingerprint: nil,
        locator: MediaLocator(relativeHint: "external.mov"),
        kind: .video,
        availabilityStatus: .external
    )
    try createBookmarkPackage(url, media: media)

    #expect(try BookmarkSidecarStore().read(mediaID: bookmarkMediaID, in: url) == nil)
    guard case .opened(let snapshot) = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("A missing bookmark must not block project opening.")
        return
    }
    #expect(snapshot.document.mediaRegistry.first?.id == bookmarkMediaID)
}

@Test("Stale bookmarks are refreshed through the raw sidecar boundary")
func staleBookmarkIsRefreshed() throws {
    let url = bookmarkPackageURL("StaleBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    try createBookmarkPackage(url)

    let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("refreshed.mov")
    let stale = Data("stale".utf8)
    let refreshed = Data("refreshed".utf8)
    let adapter = AppleBookmarkAdapter(
        create: { candidate in
            #expect(candidate == targetURL)
            return refreshed
        },
        resolve: { data in
            #expect(data == stale)
            return (targetURL, true)
        }
    )
    let store = BookmarkSidecarStore()
    try store.write(stale, mediaID: bookmarkMediaID, in: url)

    let resolved = try store.resolveAndRefreshIfNeeded(
        mediaID: bookmarkMediaID,
        in: url,
        adapter: adapter
    )
    #expect(resolved == targetURL)
    #expect(try store.read(mediaID: bookmarkMediaID, in: url) == refreshed)
}

@Test("Corrupt bookmarks fail locally without corrupting the project pair")
func corruptBookmarkIsIsolated() throws {
    let url = bookmarkPackageURL("CorruptBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    try createBookmarkPackage(url)

    let store = BookmarkSidecarStore()
    try store.write(Data("corrupt".utf8), mediaID: bookmarkMediaID, in: url)
    let adapter = AppleBookmarkAdapter(
        create: { _ in Data() },
        resolve: { _ in
            throw ProjectPersistenceError.bookmarkOperationFailed("fixture corruption")
        }
    )

    #expect(throws: ProjectPersistenceError.self) {
        try store.resolveAndRefreshIfNeeded(
            mediaID: bookmarkMediaID,
            in: url,
            adapter: adapter
        )
    }
    guard case .opened = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("A corrupt bookmark must not block project opening.")
        return
    }
}

@Test("Removing a bookmark is idempotent and leaves the project openable")
func bookmarkRemovalIsIdempotent() throws {
    let url = bookmarkPackageURL("RemoveBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    try createBookmarkPackage(url)

    let store = BookmarkSidecarStore()
    try store.write(Data("bookmark".utf8), mediaID: bookmarkMediaID, in: url)
    try store.remove(mediaID: bookmarkMediaID, in: url)
    try store.remove(mediaID: bookmarkMediaID, in: url)

    #expect(try store.read(mediaID: bookmarkMediaID, in: url) == nil)
    guard case .opened = try VertexProjectPackageStore().open(at: url) else {
        Issue.record("Removing a bookmark must not block project opening.")
        return
    }
}

@Test("Canonical project JSON excludes bookmark bytes even when a sidecar exists")
func bookmarkBytesStayOutsideCanonicalJSON() throws {
    let url = bookmarkPackageURL("JSONBookmark")
    defer { try? FileManager.default.removeItem(at: url) }
    try createBookmarkPackage(url)
    try BookmarkSidecarStore().write(Data("secret-bookmark".utf8), mediaID: bookmarkMediaID, in: url)

    let layout = try VertexProjectPackageLayout(root: url)
    let projectJSON = String(decoding: try Data(contentsOf: layout.projectURL), as: UTF8.self)
    #expect(!projectJSON.contains("bookmarkData"))
    #expect(!projectJSON.contains("secret-bookmark"))
}
