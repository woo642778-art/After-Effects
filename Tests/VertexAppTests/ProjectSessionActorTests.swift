import Foundation
import Testing
import VertexCore
import VertexProject
import VertexProjectPersistence
@testable import Vertex

private func actorPackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

@Test("Reopening a saved project starts with empty session history")
func reopenedProjectHasNoPersistentHistory() async throws {
    let url = actorPackageURL("Reopen")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Original", packageURL: url)
    let edited = try await actor.apply(
        .renameProject(to: "Edited"),
        mergeKey: nil
    )
    #expect(created.canUndo == false)
    #expect(edited.canUndo)
    #expect(edited.hasUnsavedChanges)

    let saved = try await actor.save()
    #expect(!saved.hasUnsavedChanges)

    let reopenedActor = ProjectSessionActor()
    guard case .opened(let reopened) = try await reopenedActor.openCanonical(packageURL: url) else {
        Issue.record("A verified project should open directly.")
        return
    }
    #expect(reopened.document.metadata.name == "Edited")
    #expect(!reopened.canUndo)
    #expect(!reopened.canRedo)
    #expect(!reopened.hasUnsavedChanges)
}

@Test("Autosave preserves dirty session state while explicit save clears it")
func autosaveDoesNotBecomeExplicitSave() async throws {
    let url = actorPackageURL("Autosave")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    _ = try await actor.create(name: "Autosave", packageURL: url)
    let edited = try await actor.apply(
        .setRenderParameter(.exposure, value: 1.25),
        mergeKey: "render.exposure"
    )
    let autosave = try await actor.autosave(reason: .manualFlush)
    let afterAutosave = try await actor.snapshot()

    #expect(edited.hasUnsavedChanges)
    #expect(autosave != nil)
    #expect(afterAutosave.hasUnsavedChanges)

    let saved = try await actor.save()
    #expect(!saved.hasUnsavedChanges)
    #expect(saved.savedRevision == saved.document.revision)
}

@Test("Selection changes are persisted but never added to Undo history")
func selectionIsNotUndoHistory() async throws {
    let url = actorPackageURL("Selection")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    _ = try await actor.create(name: "Selection", packageURL: url)
    let media = MediaReference(
        id: VertexID(rawValue: "58000000-0000-0000-0000-000000000001"),
        displayName: "clip.mov",
        originalFilename: "clip.mov",
        fileSize: 1,
        kind: .video,
        availabilityStatus: .missing
    )
    _ = try await actor.apply(.registerMedia(media), mergeKey: nil)
    let beforeSelection = try await actor.snapshot()
    let selected = try await actor.setSelectedMedia(media.id)

    #expect(selected.document.selectedMediaID == media.id)
    #expect(selected.undoCount == beforeSelection.undoCount)
}

@Test("Legacy packages require inspection and conversion rather than canonical opening")
func legacyPackageIsImportOnly() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Legacy-\(UUID().uuidString)", isDirectory: true)
        .appendingPathExtension("aeproject")
    defer { try? FileManager.default.removeItem(at: url) }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    let actor = ProjectSessionActor()
    do {
        _ = try await actor.openCanonical(packageURL: url)
        Issue.record("A legacy package must not open as an editable canonical package.")
    } catch is ProjectPersistenceError {
        // Expected import-only rejection.
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}
