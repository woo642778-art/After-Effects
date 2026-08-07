import Foundation
import Testing
import VertexCore
import VertexProject
import VertexProjectPersistence
@testable import Vertex

private func workspacePackageURL(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathExtension("vertexproject")
}

@Test("Composition and layer navigation survives save and reopen without persistent history")
func workspaceNavigationPersistsWithoutHistory() async throws {
    let url = workspacePackageURL("WorkspaceNavigation")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Workspace", packageURL: url)
    let main = try #require(created.document.activeCompositionID)
    let secondID = VertexID(rawValue: "69000000-0000-0000-0000-000000000010")
    let second = ProjectComposition(
        id: secondID,
        name: "Second",
        width: 1280,
        height: 720,
        duration: RationalTime(value: 12, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: []
    )
    _ = try await actor.apply(
        .createComposition(second, ownedLayers: [], index: 1),
        mergeKey: nil
    )

    let layer = ProjectLayer(
        id: VertexID(rawValue: "69000000-0000-0000-0000-000000000020"),
        compositionID: secondID,
        name: "Null",
        source: .null,
        timing: LayerTiming(
            startTime: .zero,
            inPoint: .zero,
            outPoint: second.duration
        )
    )
    _ = try await actor.apply(
        .insertLayer(layer, compositionID: secondID, index: 0),
        mergeKey: nil
    )

    let historyBeforeNavigation = try await actor.snapshot()
    let activated = try await actor.setActiveComposition(secondID)
    let selected = try await actor.setSelectedLayer(layer.id)

    #expect(activated.document.activeCompositionID == secondID)
    #expect(activated.document.selectedLayerID == nil)
    #expect(selected.document.selectedLayerID == layer.id)
    #expect(selected.undoCount == historyBeforeNavigation.undoCount)
    #expect(selected.redoCount == historyBeforeNavigation.redoCount)

    _ = try await actor.save()
    _ = try await actor.close(disposition: .discardSessionChanges)

    let reopenedActor = ProjectSessionActor()
    guard case .opened(let reopened) = try await reopenedActor.openCanonical(packageURL: url) else {
        Issue.record("Saved canonical workspace should reopen directly.")
        return
    }
    #expect(reopened.document.activeCompositionID == secondID)
    #expect(reopened.document.selectedLayerID == layer.id)
    #expect(reopened.document.composition(id: main) != nil)
    #expect(reopened.document.layer(id: layer.id) == layer)
    #expect(!reopened.canUndo)
    #expect(!reopened.canRedo)
}

@Test("Legacy Phase 6 package is converted into a new canonical package before editing")
func workspaceLegacyImportNeverEditsSourceInPlace() async throws {
    let source = FileManager.default.temporaryDirectory
        .appendingPathComponent("LegacyImport-\(UUID().uuidString)", isDirectory: true)
        .appendingPathExtension("aeproject")
    let destination = workspacePackageURL("ImportedCanonical")
    defer {
        try? FileManager.default.removeItem(at: source)
        try? FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    let actor = ProjectSessionActor()
    do {
        _ = try await actor.importLegacy(sourceURL: source, destinationURL: destination)
        Issue.record("An incomplete legacy package must fail conversion without creating a writable destination.")
    } catch is ProjectPersistenceError {
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
