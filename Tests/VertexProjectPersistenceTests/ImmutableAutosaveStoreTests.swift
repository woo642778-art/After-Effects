import Foundation
import Testing
import VertexCore
import VertexProject
@testable import VertexProjectPersistence

private func autosavePackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

private func autosaveDocument(revision: UInt64, name: String = "Autosave") throws -> ProjectDocument {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "53000000-0000-0000-0000-000000000001"),
        name: name,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    document.revision = revision
    document.metadata.modifiedAt = Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(revision))
    return try document.validated()
}

private func createAutosavePackage(_ url: URL) throws {
    _ = try VertexProjectPackageStore(
        fixedTimestamp: Date(timeIntervalSince1970: 1_700_000_000)
    ).create(at: url, document: try autosaveDocument(revision: 0))
}

@Test("Autosave names use 20-digit monotonic sequence and project checksum")
func autosaveNamesAreCanonical() throws {
    let url = autosavePackageURL("Names")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)

    let store = ImmutableAutosaveStore()
    let first = try #require(store.write(
        document: try autosaveDocument(revision: 1),
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_001)
    ))
    let second = try #require(store.write(
        document: try autosaveDocument(revision: 2),
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_002)
    ))

    #expect(first.sequence == 1)
    #expect(second.sequence == 2)
    #expect(first.url.lastPathComponent == String(format: "%020llu-%@.json", first.sequence, first.checksum))
    #expect(second.url.lastPathComponent == String(format: "%020llu-%@.json", second.sequence, second.checksum))
}

@Test("Duplicate document snapshots are suppressed without modifying existing bytes")
func duplicateAutosaveIsSuppressed() throws {
    let url = autosavePackageURL("Duplicate")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)

    let store = ImmutableAutosaveStore()
    let document = try autosaveDocument(revision: 1)
    let first = try #require(store.write(
        document: document,
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_001)
    ))
    let bytes = try Data(contentsOf: first.url)

    let duplicate = try store.write(
        document: document,
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_999)
    )
    #expect(duplicate == nil)
    #expect(try Data(contentsOf: first.url) == bytes)
}

@Test("Valid autosaves ignore malformed and corrupt entries")
func malformedAndCorruptAutosavesAreIsolated() throws {
    let url = autosavePackageURL("Isolation")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)
    let layout = try VertexProjectPackageLayout(root: url)

    let valid = try #require(ImmutableAutosaveStore().write(
        document: try autosaveDocument(revision: 1),
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_001)
    ))
    try Data("malformed".utf8).write(to: layout.autosavesDirectoryURL.appendingPathComponent("bad-name.json"))
    let corruptName = String(format: "%020llu-%@.json", 2, String(repeating: "a", count: 64))
    try Data("corrupt".utf8).write(to: layout.autosavesDirectoryURL.appendingPathComponent(corruptName))

    let records = try ImmutableAutosaveStore().validRecords(in: url)
    #expect(records.count == 1)
    #expect(records.first?.url == valid.url)
    #expect(try ImmutableAutosaveStore().latestValid(in: url)?.revision == 1)
}

@Test("Autosave retention keeps the eight newest valid unique snapshots")
func autosaveRetentionKeepsEight() throws {
    let url = autosavePackageURL("Retention")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)

    let store = ImmutableAutosaveStore()
    for revision in 1...12 {
        _ = try store.write(
            document: try autosaveDocument(revision: UInt64(revision), name: "Autosave \(revision)"),
            in: url,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(revision))
        )
    }

    let records = try store.validRecords(in: url)
    #expect(records.map(\.sequence) == Array(5...12).map(UInt64.init))
    #expect(records.map(\.revision) == Array(5...12).map(UInt64.init))
}

@Test("Autosave JSON contains no session history command inverse or bookmark state")
func autosaveJSONIsCanonical() throws {
    let url = autosavePackageURL("Canonical")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)

    let record = try #require(ImmutableAutosaveStore().write(
        document: try autosaveDocument(revision: 1),
        in: url,
        createdAt: Date(timeIntervalSince1970: 1_700_000_001)
    ))
    let json = String(decoding: try Data(contentsOf: record.url), as: UTF8.self)
    for forbidden in ["bookmarkData", "appliedCommandIDs", "legacyRenderSettings", "inverseOperation", "history", "undo", "redo"] {
        #expect(!json.contains(forbidden))
    }
}

@Test("Exhausted autosave sequence fails without overwriting bytes")
func autosaveSequenceExhaustionIsSafe() throws {
    let url = autosavePackageURL("Exhaustion")
    defer { try? FileManager.default.removeItem(at: url) }
    try createAutosavePackage(url)
    let layout = try VertexProjectPackageLayout(root: url)
    let checksum = String(repeating: "b", count: 64)
    let exhaustedURL = layout.autosavesDirectoryURL.appendingPathComponent(
        String(format: "%020llu-%@.json", UInt64.max, checksum)
    )
    let original = Data("sentinel".utf8)
    try original.write(to: exhaustedURL)

    #expect(throws: ProjectPersistenceError.self) {
        try ImmutableAutosaveStore().write(
            document: autosaveDocument(revision: 1),
            in: url,
            createdAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
    }
    #expect(try Data(contentsOf: exhaustedURL) == original)
}
