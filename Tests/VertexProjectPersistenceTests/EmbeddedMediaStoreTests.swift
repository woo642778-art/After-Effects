import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private let embeddedMediaID = VertexID(rawValue: "55000000-0000-0000-0000-000000000001")

private func embeddedPackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

private func createEmbeddedPackage(_ url: URL) throws {
    _ = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_001)
    ).create(
        at: url,
        document: try ProjectDocument.makeNew(
            id: VertexID(rawValue: "55000000-0000-0000-0000-000000000099"),
            name: "Embedded",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    )
}

private func sourceFile(name: String = "unsafe name.mov", bytes: Data = Data("media-bytes".utf8)) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent(name)
    try bytes.write(to: url)
    return url
}

private func externalReference(sourceURL: URL, fingerprint: String?) throws -> MediaReference {
    let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
    return MediaReference(
        id: embeddedMediaID,
        displayName: sourceURL.lastPathComponent,
        originalFilename: sourceURL.lastPathComponent,
        fileSize: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
        modificationDate: attributes[.modificationDate] as? Date,
        contentFingerprint: fingerprint,
        locator: MediaLocator(relativeHint: sourceURL.lastPathComponent),
        kind: .video,
        availabilityStatus: .external
    )
}

@Test("Embedded media uses deterministic sanitized names and survives source removal")
func embeddedMediaIsSelfContained() throws {
    let packageURL = embeddedPackageURL("SelfContained")
    let sourceURL = try sourceFile()
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
    }
    try createEmbeddedPackage(packageURL)

    let store = EmbeddedMediaStore()
    let fingerprint = try store.fingerprint(of: sourceURL)
    let reference = try externalReference(sourceURL: sourceURL, fingerprint: fingerprint)
    let embedded = try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)

    #expect(embedded.locator.embeddedPath == "Media/55000000-0000-0000-0000-000000000001-unsafe_name.mov")
    #expect(embedded.availabilityStatus == .embedded)
    #expect(embedded.contentFingerprint == fingerprint)

    let layout = try VertexProjectPackageLayout(root: packageURL)
    let destination = layout.root.appendingPathComponent(try #require(embedded.locator.embeddedPath))
    #expect(FileManager.default.fileExists(atPath: destination.path))
    #expect(!FileManager.default.fileExists(atPath: destination.appendingPathExtension("tmp").path))
    #expect(try BookmarkSidecarStore().read(mediaID: embeddedMediaID, in: packageURL) == nil)

    try FileManager.default.removeItem(at: sourceURL)
    #expect(try store.resolve(reference: embedded, packageURL: packageURL) == destination)
}

@Test("Embedding rejects a source whose fingerprint differs from the reference")
func embeddedMediaRejectsPreCopyMismatch() throws {
    let packageURL = embeddedPackageURL("PreMismatch")
    let sourceURL = try sourceFile()
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
    }
    try createEmbeddedPackage(packageURL)

    let reference = try externalReference(
        sourceURL: sourceURL,
        fingerprint: String(repeating: "a", count: 64)
    )
    #expect(throws: ProjectPersistenceError.self) {
        try EmbeddedMediaStore().embed(
            reference: reference,
            sourceURL: sourceURL,
            packageURL: packageURL
        )
    }

    let layout = try VertexProjectPackageLayout(root: packageURL)
    #expect(try FileManager.default.contentsOfDirectory(atPath: layout.mediaDirectoryURL.path).isEmpty)
}

@Test("An existing embedded collision with different bytes is never overwritten")
func embeddedMediaRejectsCollisionMismatch() throws {
    let packageURL = embeddedPackageURL("Collision")
    let sourceURL = try sourceFile()
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
    }
    try createEmbeddedPackage(packageURL)

    let store = EmbeddedMediaStore()
    let reference = try externalReference(sourceURL: sourceURL, fingerprint: store.fingerprint(of: sourceURL))
    let embedded = try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)
    let relativePath = try #require(embedded.locator.embeddedPath)
    let destination = try VertexProjectPackageLayout(root: packageURL).root.appendingPathComponent(relativePath)
    let collisionBytes = Data("different-collision".utf8)
    try collisionBytes.write(to: destination)

    #expect(throws: ProjectPersistenceError.self) {
        try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)
    }
    #expect(try Data(contentsOf: destination) == collisionBytes)
}

@Test("Resolve rejects tampered embedded bytes")
func embeddedResolveRejectsPostCopyMismatch() throws {
    let packageURL = embeddedPackageURL("ResolveMismatch")
    let sourceURL = try sourceFile()
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
    }
    try createEmbeddedPackage(packageURL)

    let store = EmbeddedMediaStore()
    let reference = try externalReference(sourceURL: sourceURL, fingerprint: store.fingerprint(of: sourceURL))
    let embedded = try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)
    let relativePath = try #require(embedded.locator.embeddedPath)
    let destination = try VertexProjectPackageLayout(root: packageURL).root.appendingPathComponent(relativePath)
    try Data("tampered".utf8).write(to: destination)

    #expect(throws: ProjectPersistenceError.self) {
        try store.resolve(reference: embedded, packageURL: packageURL)
    }
}

@Test("Embedding rejects traversal-like filenames while producing a safe deterministic file")
func embeddedMediaSanitizesTraversalName() throws {
    let packageURL = embeddedPackageURL("TraversalName")
    let sourceURL = try sourceFile(name: ".. weird/clip.mov".replacingOccurrences(of: "/", with: "_"))
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
    }
    try createEmbeddedPackage(packageURL)

    let store = EmbeddedMediaStore()
    let reference = try externalReference(sourceURL: sourceURL, fingerprint: store.fingerprint(of: sourceURL))
    let embedded = try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)
    let relativePath = try #require(embedded.locator.embeddedPath)

    #expect(relativePath.hasPrefix("Media/55000000-0000-0000-0000-000000000001-"))
    #expect(!relativePath.contains(".."))
    #expect(!relativePath.dropFirst("Media/".count).contains("/"))
}
