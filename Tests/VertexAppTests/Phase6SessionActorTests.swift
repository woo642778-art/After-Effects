import Foundation
import Testing
import VertexCore
import VertexProject
@testable import Vertex

private func phase6ActorURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("phase6-actor-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent(name)
        .appendingPathExtension("vertexproject")
}

@Test("Composition and layer edits persist through actor save and reopen with empty history")
func phase6ActorRoundTrip() async throws {
    let url = phase6ActorURL("RoundTrip")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Phase 6", packageURL: url)
    let compositionID = try #require(created.document.activeCompositionID)
    let layer = ProjectLayer(
        id: VertexID(rawValue: "68000000-0000-0000-0000-000000000001"),
        compositionID: compositionID,
        name: "Adjustment",
        source: .adjustment(scope: .belowAll),
        timing: LayerTiming(
            startTime: .zero,
            inPoint: .zero,
            outPoint: created.document.composition(id: compositionID)!.duration
        ),
        operations: [.exposure(stops: 1)]
    )
    let inserted = try await actor.apply(.insertLayer(layer, index: 0), mergeKey: nil)
    #expect(inserted.document.layer(id: layer.id) != nil)
    #expect(inserted.canUndo)

    let transformed = LayerTransform(
        positionX: 0.5,
        positionY: 0.5,
        anchorX: 0.5,
        anchorY: 0.5,
        scaleX: 1,
        scaleY: 1,
        rotationDegrees: 0,
        opacity: 0.5
    )
    let edited = try await actor.apply(
        .setLayerTransform(id: layer.id, transform: transformed),
        mergeKey: "layer.\(layer.id.rawValue).opacity"
    )
    #expect(edited.document.layer(id: layer.id)?.transform.opacity == 0.5)
    _ = try await actor.save()

    let reopenedActor = ProjectSessionActor()
    guard case .opened(let reopened) = try await reopenedActor.openCanonical(packageURL: url) else {
        Issue.record("Saved schema 2 package should reopen directly.")
        return
    }
    #expect(reopened.document.layer(id: layer.id)?.transform.opacity == 0.5)
    #expect(!reopened.canUndo)
    #expect(!reopened.canRedo)
    #expect(!reopened.hasUnsavedChanges)
}

@Test("Composition and layer navigation remain outside Undo history")
func phase6NavigationIsNotHistory() async throws {
    let url = phase6ActorURL("Navigation")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Navigation", packageURL: url)
    let firstID = try #require(created.document.activeCompositionID)
    let second = ProjectComposition(
        id: VertexID(rawValue: "68000000-0000-0000-0000-000000000010"),
        name: "Second",
        width: 640,
        height: 360,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: []
    )
    let inserted = try await actor.apply(.insertComposition(second, ownedLayers: [], index: 1), mergeKey: nil)
    let undoCount = inserted.undoCount
    let selected = try await actor.setActiveComposition(second.id)
    #expect(selected.document.activeCompositionID == second.id)
    #expect(selected.undoCount == undoCount)
    let back = try await actor.setActiveComposition(firstID)
    #expect(back.document.activeCompositionID == firstID)
    #expect(back.undoCount == undoCount)
}
