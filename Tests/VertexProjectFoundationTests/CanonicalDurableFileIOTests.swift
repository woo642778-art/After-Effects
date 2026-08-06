import Foundation
import Testing
@testable import VertexProjectPersistence

private func temporaryPersistenceDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test("Durable write and atomic promotion preserve exact bytes")
func canonicalDurableWriteAndPromotion() throws {
    let directory = try temporaryPersistenceDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let temporary = directory.appendingPathComponent("value.tmp")
    let destination = directory.appendingPathComponent("value.json")
    let bytes = Data("canonical".utf8)
    let io = DurableFileIO()
    try io.writeAndSynchronize(bytes, to: temporary)
    try io.atomicPromote(temporary, to: destination)
    try io.synchronizeDirectory(directory)
    #expect(try Data(contentsOf: destination) == bytes)
    #expect(!FileManager.default.fileExists(atPath: temporary.path))
}

@Test("Atomic promotion replaces destination without a backup")
func canonicalAtomicPromotionReplacesDestination() throws {
    let directory = try temporaryPersistenceDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let temporary = directory.appendingPathComponent("value.tmp")
    let destination = directory.appendingPathComponent("value.json")
    try Data("old".utf8).write(to: destination)
    let io = DurableFileIO()
    try io.writeAndSynchronize(Data("new".utf8), to: temporary)
    try io.atomicPromote(temporary, to: destination)
    #expect(try Data(contentsOf: destination) == Data("new".utf8))
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["value.json"])
}

@Test("Durable IO injected failures occur at exact boundaries")
func canonicalDurableFailureBoundaries() throws {
    for point in DurableFileFailurePoint.allCases {
        let directory = try temporaryPersistenceDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let temporary = directory.appendingPathComponent("value.tmp")
        let destination = directory.appendingPathComponent("value.json")
        let io = DurableFileIO(failurePoint: point)
        switch point {
        case .afterWrite, .afterFileSync:
            #expect(throws: ProjectPersistenceError.self) {
                try io.writeAndSynchronize(Data("bytes".utf8), to: temporary)
            }
        case .afterRename:
            try DurableFileIO().writeAndSynchronize(Data("bytes".utf8), to: temporary)
            #expect(throws: ProjectPersistenceError.self) {
                try io.atomicPromote(temporary, to: destination)
            }
        case .afterDirectorySync:
            #expect(throws: ProjectPersistenceError.self) {
                try io.synchronizeDirectory(directory)
            }
        }
    }
}
