import Foundation
import Testing
@testable import VertexProjectPersistence

private func temporaryCanonicalPackage(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

@Test("Canonical package creates only the required directories")
func canonicalPackageCreatesRequiredDirectories() throws {
    let root = temporaryCanonicalPackage()
    defer { try? FileManager.default.removeItem(at: root) }
    let layout = try VertexProjectPackageLayout(root: root)
    try layout.createRequiredDirectories(fileManager: .default)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["Autosaves", "Bookmarks", "Journal", "Media"])
}

@Test("Canonical steady state accepts only exact root entries")
func canonicalPackageAcceptsExactAllowlist() throws {
    let root = temporaryCanonicalPackage()
    defer { try? FileManager.default.removeItem(at: root) }
    let layout = try VertexProjectPackageLayout(root: root)
    try layout.createRequiredDirectories(fileManager: .default)
    try Data("{}".utf8).write(to: layout.projectURL)
    try Data("{}".utf8).write(to: layout.manifestURL)
    try layout.validateAllowlist(fileManager: .default, mode: .steadyState)
}

@Test("Legacy extension and forbidden persistence entries are rejected")
func canonicalPackageRejectsLegacyEntries() throws {
    let legacy = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathExtension("aeproject")
    #expect(throws: ProjectPersistenceError.self) {
        try VertexProjectPackageLayout(root: legacy)
    }

    for forbidden in ["history.json", "project.json.backup", "operations.log", "snapshot-current.json", "snapshot-previous.json", "proxies", "thumbnails", "recovery", "quarantine"] {
        let root = temporaryCanonicalPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = try VertexProjectPackageLayout(root: root)
        try layout.createRequiredDirectories(fileManager: .default)
        let url = root.appendingPathComponent(forbidden, isDirectory: !forbidden.contains("."))
        if forbidden.contains(".") { try Data().write(to: url) }
        else { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        #expect(throws: ProjectPersistenceError.self) {
            try layout.validateAllowlist(fileManager: .default, mode: .steadyState)
        }
    }
}

@Test("Only exact transaction temporary names are accepted")
func canonicalPackageRecognizesTemporaryNames() throws {
    let root = temporaryCanonicalPackage()
    defer { try? FileManager.default.removeItem(at: root) }
    let layout = try VertexProjectPackageLayout(root: root)
    try layout.createRequiredDirectories(fileManager: .default)
    try Data().write(to: layout.projectTemporaryURL)
    try Data().write(to: layout.manifestTemporaryURL)
    try Data().write(to: layout.pendingSaveTemporaryURL)
    try layout.validateAllowlist(fileManager: .default, mode: .transactionRecovery)
    try Data().write(to: root.appendingPathComponent("unknown.tmp"))
    #expect(throws: ProjectPersistenceError.self) {
        try layout.validateAllowlist(fileManager: .default, mode: .transactionRecovery)
    }
}
