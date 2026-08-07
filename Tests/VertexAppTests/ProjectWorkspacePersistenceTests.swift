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

private func fullLayerTiming(_ composition: ProjectComposition) -> LayerTiming {
    LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
}

@Test("Composition and layer edits flow through one serial project session")
func compositionLayerEditsUseActorSession() async throws {
    let url = workspacePackageURL("CompositionSession")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Composition Session", packageURL: url)
    let main = try #require(created.document.activeCompositionID.flatMap { created.document.composition(id: $0) })
    let bottomID = VertexID(rawValue: "68000000-0000-0000-0000-000000000001")
    let topID = VertexID(rawValue: "68000000-0000-0000-0000-000000000002")
    let bottom = ProjectLayer(
        id: bottomID,
        compositionID: main.id,
        name: "Bottom",
        source: .adjustment(scope: .belowAll),
        timing: fullLayerTiming(main)
    )
    let top = ProjectLayer(
        id: topID,
        compositionID: main.id,
        name: "Top",
        source: .adjustment(scope: .belowAll),
        timing: fullLayerTiming(main)
    )

    _ = try await actor.apply(.insertLayer(bottom, compositionID: main.id, index: 0), mergeKey: nil)
    _ = try await actor.apply(.insertLayer(top, compositionID: main.id, index: 1), mergeKey: nil)
    _ = try await actor.apply(
        .reorderLayer(compositionID: main.id, layerID: topID, toIndex: 0),
        mergeKey: nil
    )

    var moved = LayerTransform.identity
    moved.positionX = 0.6
    let firstTransform = try await actor.apply(
        .setLayerTransform(id: topID, value: moved),
        mergeKey: "layer.\(topID.rawValue).position"
    )
    moved.positionX = 0.7
    let secondTransform = try await actor.apply(
        .setLayerTransform(id: topID, value: moved),
        mergeKey: "layer.\(topID.rawValue).position"
    )
    #expect(secondTransform.undoCount == firstTransform.undoCount)

    let beforeNavigationUndo = secondTransform.undoCount
    let selectedComposition = try await actor.setActiveComposition(main.id)
    let selectedLayer = try await actor.setSelectedLayer(topID)
    #expect(selectedComposition.undoCount == beforeNavigationUndo)
    #expect(selectedLayer.undoCount == beforeNavigationUndo)
    #expect(selectedLayer.document.selectedLayerID == topID)
    #expect(selectedLayer.document.layers(in: main.id).map(\.id) == [topID, bottomID])

    _ = try await actor.apply(.setLayerLocked(id: topID, value: true), mergeKey: nil)
    await #expect(throws: ProjectError.self) {
        _ = try await actor.apply(.renameLayer(id: topID, to: "Blocked"), mergeKey: nil)
    }
}

@Test("Nested-cycle rejection and exact composition duplication survive save and reopen")
func compositionPersistenceRoundTrip() async throws {
    let url = workspacePackageURL("CompositionRoundTrip")
    defer { try? FileManager.default.removeItem(at: url) }

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Round Trip", packageURL: url)
    let main = try #require(created.document.activeCompositionID.flatMap { created.document.composition(id: $0) })
    let childID = VertexID(rawValue: "68000000-0000-0000-0000-000000000010")
    let child = ProjectComposition(
        id: childID,
        name: "Child",
        width: main.width,
        height: main.height,
        duration: main.duration,
        frameRate: main.frameRate,
        color: main.color
    )
    _ = try await actor.apply(
        .createComposition(child, ownedLayers: [], index: 1),
        mergeKey: nil
    )
    let nestedID = VertexID(rawValue: "68000000-0000-0000-0000-000000000011")
    let nested = ProjectLayer(
        id: nestedID,
        compositionID: main.id,
        name: "Nested Child",
        source: .composition(compositionID: childID, sourceStartTime: .zero),
        timing: fullLayerTiming(main)
    )
    _ = try await actor.apply(.insertLayer(nested, compositionID: main.id, index: 0), mergeKey: nil)

    await #expect(throws: ProjectError.self) {
        _ = try await actor.apply(.removeComposition(id: childID), mergeKey: nil)
    }
    let saved = try await actor.save()
    #expect(saved.document.layer(id: nestedID) != nil)

    let reopenedActor = ProjectSessionActor()
    guard case .opened(let reopened) = try await reopenedActor.openCanonical(packageURL: url) else {
        Issue.record("A verified composition package should reopen directly.")
        return
    }
    #expect(reopened.document.composition(id: childID) != nil)
    #expect(reopened.document.layer(id: nestedID) != nil)
    #expect(!reopened.canUndo)
    #expect(!reopened.canRedo)
}

@Test("Verified embedded media resolves while unrelated missing media stays isolated")
func embeddedMediaResolutionIsIsolated() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("EmbeddedIsolation-\(UUID().uuidString)", isDirectory: true)
    let url = root.appendingPathComponent("Project.vertexproject", isDirectory: true)
    let source = root.appendingPathComponent("embedded.bin")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let bytes = Data("embedded-frame-source".utf8)
    try bytes.write(to: source)

    let actor = ProjectSessionActor()
    let created = try await actor.create(name: "Media Isolation", packageURL: url)
    let embeddedID = VertexID(rawValue: "68000000-0000-0000-0000-000000000020")
    let missingID = VertexID(rawValue: "68000000-0000-0000-0000-000000000021")
    let fingerprint = StableProjectSHA256.hexDigest(bytes)
    let embeddedReference = MediaReference(
        id: embeddedID,
        displayName: source.lastPathComponent,
        originalFilename: source.lastPathComponent,
        fileSize: Int64(bytes.count),
        modificationDate: nil,
        contentFingerprint: fingerprint,
        locator: MediaLocator(relativeHint: source.lastPathComponent),
        kind: .video,
        availabilityStatus: .external
    )
    let missingReference = MediaReference(
        id: missingID,
        displayName: "missing.mov",
        originalFilename: "missing.mov",
        fileSize: 1,
        modificationDate: nil,
        contentFingerprint: nil,
        locator: MediaLocator(relativeHint: "missing.mov"),
        kind: .video,
        availabilityStatus: .missing
    )
    _ = try await actor.apply(.registerMedia(embeddedReference), mergeKey: nil)
    _ = try await actor.apply(.registerMedia(missingReference), mergeKey: nil)
    let embedded = try await actor.embed(mediaID: embeddedID, from: source)
    try FileManager.default.removeItem(at: source)
    let snapshot = try await actor.snapshot()

    #expect(created.missingMediaIDs.isEmpty)
    #expect(embedded.document.mediaRegistry.first { $0.id == embeddedID }?.availabilityStatus == .embedded)
    #expect(!snapshot.missingMediaIDs.contains(embeddedID))
    #expect(snapshot.missingMediaIDs.contains(missingID))
}
