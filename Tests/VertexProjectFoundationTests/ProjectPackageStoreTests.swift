import Foundation
import Testing
@testable import VertexProjectFoundation
import VertexProject
import VertexCore

private func temporaryPackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name)
        .appendingPathExtension("aeproject")
}

@Test("Package-relative paths cannot escape the package")
func pathTraversalIsRejected() throws {
    let layout = try ProjectPackageLayout(root: temporaryPackageURL("Traversal"))
    #expect(throws: ProjectError.self) {
        try layout.embeddedMediaURL(relativePath: "../escape.mov")
    }
    #expect(throws: ProjectError.self) {
        try layout.embeddedMediaURL(relativePath: "/absolute.mov")
    }
}

@Test("Atomic create produces matching manifest project and history")
func manifestMatchesProject() throws {
    let url = temporaryPackageURL("Atomic")
    defer { try? FileManager.default.removeItem(at: url) }
    let document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000040"),
        name: "Atomic",
        timestamp: Date(timeIntervalSince1970: 100)
    )
    let history = ProjectHistorySnapshot()
    let result = try ProjectPackageStore().create(at: url, document: document, history: history)
    #expect(result.manifest.projectChecksum == try DeterministicProjectCodec().checksum(result.document))
    #expect(result.history == history)
    #expect(FileManager.default.fileExists(atPath: result.layout.projectURL.path))
    #expect(FileManager.default.fileExists(atPath: result.layout.manifestURL.path))
    #expect(FileManager.default.fileExists(atPath: result.layout.historyURL.path))
}

@Test("Interrupted temporary writes preserve the previous project")
func interruptedWritePreservesCurrent() throws {
    let url = temporaryPackageURL("Interrupted")
    defer { try? FileManager.default.removeItem(at: url) }
    let original = try ProjectDocument.makeNew(name: "Original", timestamp: Date(timeIntervalSince1970: 100))
    _ = try ProjectPackageStore().create(at: url, document: original)

    var changed = original
    changed.metadata.name = "Changed"
    let faulting = ProjectPackageStore(failurePoint: .afterTemporaryProjectWrite)
    #expect(throws: ProjectError.self) {
        try faulting.save(changed, to: url, committedJournalSequence: 0)
    }
    #expect(try ProjectPackageStore().load(from: url).document.metadata.name == "Original")
}

@Test("History survives package save and load")
func historySurvivesSave() throws {
    let url = temporaryPackageURL("History")
    defer { try? FileManager.default.removeItem(at: url) }
    let project = try ProjectDocument.makeNew(name: "History", timestamp: Date(timeIntervalSince1970: 100))
    let controller = try ProjectHistoryController(project: project)
    try controller.perform(
        .setRenderParameter(.exposure, before: 0, after: 1),
        timestamp: Date(timeIntervalSince1970: 101),
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000041")
    )
    _ = try ProjectPackageStore().create(at: url, document: controller.project, history: controller.snapshot)
    let loaded = try ProjectPackageStore().load(from: url)
    let restored = try ProjectHistoryController(project: loaded.document, snapshot: loaded.history)
    #expect(restored.canUndo)
    try restored.undo(commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000042"))
    #expect(restored.project.renderSettings.exposure == 0)
}

@Test("Journal append writes complete durable records")
func journalAppendRoundTrips() throws {
    let url = temporaryPackageURL("JournalPackage")
    defer { try? FileManager.default.removeItem(at: url) }
    let project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000043"),
        name: "Journal",
        timestamp: Date(timeIntervalSince1970: 100)
    )
    _ = try ProjectPackageStore().create(at: url, document: project)
    let command = ProjectCommandRecord.settingExposure(
        project: project,
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000044"),
        from: 0,
        to: 1,
        timestamp: Date(timeIntervalSince1970: 101)
    )
    try ProjectPackageStore().appendJournal(
        try ProjectJournalRecord(sequence: 1, command: command),
        to: url
    )
    let loaded = try ProjectPackageStore().load(from: url)
    #expect(loaded.journalAnalysis.validRecords.count == 1)
}
