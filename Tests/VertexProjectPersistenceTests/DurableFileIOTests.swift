import Foundation
import Testing
@testable import VertexProjectPersistence

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test("Durable write and atomic promotion preserve exact bytes")
func durableWriteAndPromotion() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let temporary = directory.appendingPathComponent("value.tmp")
    let destination = directory.appendingPathComponent("value.json")
    let bytes = Data("canonical".utf8)
    let io = DurableFileIO()

    try io.writeAndSynchronize(bytes, to: temporary)
    #expect(try Data(contentsOf: temporary) == bytes)
    try io.atomicPromote(temporary, to: destination)
    try io.synchronizeDirectory(directory)

    #expect(!FileManager.default.fileExists(atPath: temporary.path))
    #expect(try Data(contentsOf: destination) == bytes)
}

@Test("Atomic promotion replaces destination without creating backups")
func atomicPromotionReplacesDestination() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let temporary = directory.appendingPathComponent("value.tmp")
    let destination = directory.appendingPathComponent("value.json")
    try Data("old".utf8).write(to: destination)
    let io = DurableFileIO()

    try io.writeAndSynchronize(Data("new".utf8), to: temporary)
    try io.atomicPromote(temporary, to: destination)

    #expect(try Data(contentsOf: destination) == Data("new".utf8))
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(names == ["value.json"])
}

@Test("Injected durable IO failures are reported at exact boundaries")
func injectedFailureBoundaries() throws {
    for point in DurableFileFailurePoint.allCases {
        let directory = try temporaryDirectory()
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

@Test("removeIfPresent is idempotent")
func removeIfPresentIsIdempotent() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("value.tmp")
    try Data().write(to: url)
    let io = DurableFileIO()

    try io.removeIfPresent(url)
    try io.removeIfPresent(url)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}
