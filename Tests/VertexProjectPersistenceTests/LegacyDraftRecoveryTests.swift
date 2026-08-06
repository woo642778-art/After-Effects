import Foundation
import Testing
@testable import VertexProjectPersistence
import VertexProject
import VertexCore

private func recoveryTemporaryPackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name)
        .appendingPathExtension("aeproject")
}

@Test("Autosave rotation keeps current previous and two hourly snapshots")
func autosaveRetentionIsBounded() throws {
    let url = recoveryTemporaryPackageURL("Autosaves")
    defer { try? FileManager.default.removeItem(at: url) }
    let base = try ProjectDocument.makeNew(name: "Autosave", timestamp: Date(timeIntervalSince1970: 0))
    _ = try ProjectPackageStore().create(at: url, document: base)
    let autosaves = ProjectAutosaveStore()

    for revision in 1...8 {
        var document = base
        document.revision = UInt64(revision)
        document.metadata.modifiedAt = Date(timeIntervalSince1970: Double(revision * 3_600))
        try autosaves.rotate(
            document: document,
            history: ProjectHistorySnapshot(),
            in: url,
            timestamp: document.metadata.modifiedAt
        )
    }
    #expect(try autosaves.snapshotURLs(in: url).count <= 4)
}

@Test("A corrupt current project recovers from valid backup into a new package")
func backupRecoveryCreatesCopy() throws {
    let url = recoveryTemporaryPackageURL("Recovery")
    let parent = url.deletingLastPathComponent()
    defer {
        try? FileManager.default.removeItem(at: url)
        if let names = try? FileManager.default.contentsOfDirectory(atPath: parent.path) {
            for name in names where name.hasPrefix("Recovery-recovered-") || name.hasPrefix("Recovery-recovery-source-") {
                try? FileManager.default.removeItem(at: parent.appendingPathComponent(name))
            }
        }
    }

    let original = try ProjectDocument.makeNew(name: "Original", timestamp: Date(timeIntervalSince1970: 100))
    _ = try ProjectPackageStore().create(at: url, document: original)
    var changed = original
    changed.revision = 1
    changed.metadata.name = "Changed"
    changed.metadata.modifiedAt = Date(timeIntervalSince1970: 101)
    _ = try ProjectPackageStore().save(changed, to: url, committedJournalSequence: 0)

    let layout = try ProjectPackageLayout(root: url)
    try Data("corrupt".utf8).write(to: layout.projectURL)

    let inspection = try ProjectRecoveryEngine().inspect(packageURL: url)
    #expect(inspection.candidates.contains { $0.source == .backup && $0.isValid })
    let recoveredURL = try ProjectRecoveryEngine().recover(
        inspection.bestCandidate!,
        from: inspection,
        timestamp: Date(timeIntervalSince1970: 200)
    )
    #expect(recoveredURL != url)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(try ProjectPackageStore().load(from: recoveredURL).document.metadata.name == "Original")
}

@Test("Backup recovery does not reuse history from a newer project revision")
func backupHistoryIsIsolated() throws {
    let url = recoveryTemporaryPackageURL("BackupHistory")
    defer { try? FileManager.default.removeItem(at: url) }

    let original = try ProjectDocument.makeNew(name: "Backup", timestamp: Date(timeIntervalSince1970: 100))
    _ = try ProjectPackageStore().create(at: url, document: original)
    let controller = try ProjectHistoryController(project: original)
    try controller.perform(
        .setRenderParameter(.exposure, before: 0, after: 1),
        timestamp: Date(timeIntervalSince1970: 101),
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000051")
    )
    _ = try ProjectPackageStore().save(
        controller.project,
        history: controller.snapshot,
        to: url,
        committedJournalSequence: 0
    )

    let layout = try ProjectPackageLayout(root: url)
    try Data("corrupt".utf8).write(to: layout.projectURL)
    let inspection = try ProjectRecoveryEngine().inspect(packageURL: url)
    let backup = try #require(inspection.candidates.first { $0.source == .backup && $0.isValid })
    #expect(backup.document?.renderSettings.exposure == 0)
    #expect(backup.history.undo.isEmpty)
    #expect(backup.history.redo.isEmpty)
}

@Test("Media embedding verifies fingerprint and works without external original")
func embeddedMediaIsSelfContained() throws {
    let packageURL = recoveryTemporaryPackageURL("Embedded")
    let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("source-\(UUID().uuidString).mov")
    defer {
        try? FileManager.default.removeItem(at: packageURL)
        try? FileManager.default.removeItem(at: sourceURL)
    }
    try Data("media-fixture".utf8).write(to: sourceURL)
    let project = try ProjectDocument.makeNew(name: "Embedded")
    _ = try ProjectPackageStore().create(at: packageURL, document: project)
    let store = ProjectMediaStore()
    let fingerprint = try store.fingerprint(of: sourceURL)
    let reference = MediaReference(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000050"),
        displayName: "source.mov",
        originalFilename: "source.mov",
        fileSize: Int64(try Data(contentsOf: sourceURL).count),
        modificationDate: nil,
        contentFingerprint: fingerprint,
        kind: .video,
        availabilityStatus: .external
    )
    let embedded = try store.embed(reference: reference, sourceURL: sourceURL, packageURL: packageURL)
    try FileManager.default.removeItem(at: sourceURL)
    #expect(embedded.availabilityStatus == .embedded)
    #expect(try store.resolveEmbedded(reference: embedded, packageURL: packageURL) != nil)
}
