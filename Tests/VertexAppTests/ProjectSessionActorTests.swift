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
        .renameProject(to: "Autosave Edited"),
        mergeKey: nil
    )
    let autosave = try await actor.autosave(reason: .manualFlush)
    let duplicateAutosave = try await actor.autosave(reason: .manualFlush)
    let afterAutosave = try await actor.snapshot()

    #expect(edited.hasUnsavedChanges)
    #expect(autosave != nil)
    #expect(duplicateAutosave == nil)
    #expect(afterAutosave.hasUnsavedChanges)

    let saved = try await actor.save()
    #expect(!saved.hasUnsavedChanges)
    #expect(saved.savedRevision == saved.document.revision)

    let repeatedSave = try await actor.save()
    #expect(repeatedSave.lastSavedAt == saved.lastSavedAt)
    #expect(repeatedSave.savedRevision == saved.savedRevision)
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
        modificationDate: nil,
        contentFingerprint: nil,
        kind: .video,
        availabilityStatus: .missing
    )
    _ = try await actor.apply(.registerMedia(media), mergeKey: nil)
    let beforeSelection = try await actor.snapshot()
    let selected = try await actor.setSelectedMedia(media.id)

    #expect(selected.document.selectedMediaID == media.id)
    #expect(selected.undoCount == beforeSelection.undoCount)
}

@Test("Save failure preserves working document and Undo history")
func saveFailurePreservesSessionState() async throws {
    let url = actorPackageURL("SaveFailure")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    _ = try await actor.create(name: "Original", packageURL: url)
    let edited = try await actor.apply(.renameProject(to: "Dirty"), mergeKey: nil)
    #expect(edited.canUndo)
    #expect(edited.hasUnsavedChanges)

    let forbidden = url.appendingPathComponent("history.json")
    try Data("forbidden".utf8).write(to: forbidden)

    do {
        _ = try await actor.save()
        Issue.record("Save must fail while the canonical package contains a forbidden entry.")
    } catch is ProjectPersistenceError {
        // Expected.
    }

    let afterFailure = try await actor.snapshot()
    #expect(afterFailure.document.metadata.name == "Dirty")
    #expect(afterFailure.document.revision == edited.document.revision)
    #expect(afterFailure.canUndo)
    #expect(afterFailure.hasUnsavedChanges)

    try FileManager.default.removeItem(at: forbidden)
    let recoveredSave = try await actor.save()
    #expect(!recoveredSave.hasUnsavedChanges)
}

@Test("Continuous layer transforms with the same merge key coalesce into one Undo entry")
func actorCoalescesCompatibleEdits() async throws {
    let url = actorPackageURL("Coalescing")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Coalescing", packageURL: url)
    let compositionID = try #require(created.document.activeCompositionID)
    let composition = try #require(created.document.composition(id: compositionID))
    let layerID = VertexID(rawValue: "58000000-0000-0000-0000-000000000010")
    let layer = ProjectLayer(
        id: layerID,
        compositionID: compositionID,
        name: "Adjustment",
        source: .adjustment(scope: .belowAll),
        timing: LayerTiming(
            startTime: .zero,
            inPoint: .zero,
            outPoint: composition.duration
        )
    )
    _ = try await actor.apply(.insertLayer(layer, index: 0), mergeKey: nil)
    _ = try await actor.save()

    guard case .opened(let reopened) = try await actor.openCanonical(packageURL: url) else {
        Issue.record("Saved package should reopen directly before coalescing edits.")
        return
    }
    #expect(reopened.undoCount == 0)

    let firstTransform = LayerTransform(
        positionX: 0.5,
        positionY: 0.5,
        anchorX: 0.5,
        anchorY: 0.5,
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0,
        opacity: 0.75
    )
    let secondTransform = LayerTransform(
        positionX: 0.5,
        positionY: 0.5,
        anchorX: 0.5,
        anchorY: 0.5,
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0,
        opacity: 0.5
    )

    let first = try await actor.apply(
        .setLayerTransform(id: layerID, transform: firstTransform),
        mergeKey: "layer.\(layerID.rawValue).transform"
    )
    let second = try await actor.apply(
        .setLayerTransform(id: layerID, transform: secondTransform),
        mergeKey: "layer.\(layerID.rawValue).transform"
    )

    #expect(first.undoCount == 1)
    #expect(second.undoCount == 1)
    #expect(second.document.layer(id: layerID)?.transform.opacity == 0.5)

    let undone = try await actor.undo()
    #expect(undone.document.layer(id: layerID)?.transform.opacity == 1.0)
    #expect(!undone.canUndo)
    #expect(undone.canRedo)
}

@Test("Close cancel preserves the session while discard clears it")
func closeCancelAndDiscard() async throws {
    let url = actorPackageURL("CloseDiscard")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    _ = try await actor.create(name: "Close", packageURL: url)
    _ = try await actor.apply(.renameProject(to: "Dirty Close"), mergeKey: nil)

    let cancelled = try await actor.close(disposition: .cancel)
    #expect(cancelled?.document.metadata.name == "Dirty Close")
    #expect(cancelled?.hasUnsavedChanges == true)

    let discarded = try await actor.close(disposition: .discardSessionChanges)
    #expect(discarded == nil)

    do {
        _ = try await actor.snapshot()
        Issue.record("Discarded sessions must no longer be readable.")
    } catch {
        // Expected.
    }
}

@Test("Save and close persists the working document and clears session history")
func closeSaveAndClose() async throws {
    let url = actorPackageURL("CloseSave")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    _ = try await actor.create(name: "Original", packageURL: url)
    _ = try await actor.apply(.renameProject(to: "Persisted"), mergeKey: nil)
    let closed = try await actor.close(disposition: .saveAndClose)
    #expect(closed == nil)

    let reopenedActor = ProjectSessionActor()
    guard case .opened(let reopened) = try await reopenedActor.openCanonical(packageURL: url) else {
        Issue.record("A saved closed project should reopen directly.")
        return
    }
    #expect(reopened.document.metadata.name == "Persisted")
    #expect(!reopened.canUndo)
    #expect(!reopened.canRedo)
    #expect(!reopened.hasUnsavedChanges)
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