import Foundation
import Testing
import VertexCore
@testable import VertexProject

private struct LayerCommandFixture {
    var document: ProjectDocument
    var composition: ProjectComposition
    var top: ProjectLayer
    var bottom: ProjectLayer
}

private func makeLayerCommandFixture() throws -> LayerCommandFixture {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000001"),
        name: "Commands",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let media = MediaReference.fixture(id: "62000000-0000-0000-0000-000000000010")
    document.mediaRegistry = [media]
    var composition = document.compositionRegistry[0]
    let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    let top = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000021"),
        compositionID: composition.id,
        name: "Top",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: timing
    )
    let bottom = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000022"),
        compositionID: composition.id,
        name: "Bottom",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: timing
    )
    composition.layerIDs = [top.id, bottom.id]
    document.compositionRegistry = [composition]
    document.layerRegistry = [top, bottom]
    document.activeCompositionID = composition.id
    document.selectedLayerID = top.id
    document.selectedMediaID = media.id
    return LayerCommandFixture(
        document: try document.validated(),
        composition: composition,
        top: top,
        bottom: bottom
    )
}

private func request(
    for document: ProjectDocument,
    id: String,
    timestamp: TimeInterval,
    mergeKey: String? = nil,
    payload: ProjectCommandPayload
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        commandID: VertexID(rawValue: id),
        projectID: document.projectID,
        baseRevision: document.revision,
        timestamp: Date(timeIntervalSince1970: timestamp),
        mergeKey: mergeKey,
        payload: payload
    )
}

@Test("Desired-state reorder derives an exact inverse and Undo restores Z-order")
func layerReorderUndoRestoresExactOrder() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document)
    let transition = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000101",
        timestamp: 10,
        payload: .reorderLayer(
            compositionID: fixture.composition.id,
            layerID: fixture.bottom.id,
            toIndex: 0
        )
    ))

    #expect(transition.forward == .reorderLayer(
        compositionID: fixture.composition.id,
        layerID: fixture.bottom.id,
        beforeIndex: 1,
        afterIndex: 0
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.bottom.id, fixture.top.id])
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000102"),
        timestamp: Date(timeIntervalSince1970: 11)
    )
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Layer insertion and removal restore the same identity and index")
func layerInsertRemoveRoundTrip() throws {
    let fixture = try makeLayerCommandFixture()
    let third = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000023"),
        compositionID: fixture.composition.id,
        name: "Third",
        source: .null,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: fixture.composition.duration)
    )
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000103",
        timestamp: 12,
        payload: .insertLayer(third, compositionID: fixture.composition.id, index: 1)
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000104"),
        timestamp: Date(timeIntervalSince1970: 13)
    )
    #expect(session.document.layer(id: third.id) == nil)
    _ = try session.redo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000105"),
        timestamp: Date(timeIntervalSince1970: 14)
    )
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
}

@Test("Locked layers reject edits except an explicit unlock request")
func lockedLayerPreconditions() throws {
    var fixture = try makeLayerCommandFixture()
    fixture.top.locked = true
    fixture.document.layerRegistry = [fixture.top, fixture.bottom]
    fixture.document = try fixture.document.validated()
    var session = try ProjectEditingSession(document: fixture.document)
    var changed = fixture.top.transform
    changed.positionX = 0.7

    #expect(throws: ProjectError.self) {
        try session.apply(request(
            for: session.document,
            id: "62000000-0000-0000-0000-000000000106",
            timestamp: 15,
            payload: .setLayerTransform(id: fixture.top.id, value: changed)
        ))
    }

    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000107",
        timestamp: 16,
        payload: .setLayerLocked(id: fixture.top.id, value: false)
    ))
    #expect(session.document.layer(id: fixture.top.id)?.locked == false)
}

@Test("A composition referenced by a nested layer cannot be removed")
func referencedCompositionCannotBeRemoved() throws {
    var fixture = try makeLayerCommandFixture()
    let child = ProjectComposition(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000040"),
        name: "Child",
        width: 640,
        height: 360,
        duration: RationalTime(value: 10, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        layerIDs: []
    )
    let nested = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000041"),
        compositionID: fixture.composition.id,
        name: "Nested Child",
        source: .composition(compositionID: child.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: fixture.composition.duration)
    )
    fixture.composition.layerIDs.insert(nested.id, at: 0)
    fixture.document.compositionRegistry = [fixture.composition, child]
    fixture.document.layerRegistry.append(nested)
    fixture.document = try fixture.document.validated()
    var session = try ProjectEditingSession(document: fixture.document)

    #expect(throws: ProjectError.self) {
        try session.apply(request(
            for: session.document,
            id: "62000000-0000-0000-0000-000000000108",
            timestamp: 17,
            payload: .removeComposition(id: child.id)
        ))
    }
}

@Test("Chained desired-state transforms coalesce into one Undo entry")
func layerTransformCommandsCoalesce() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document, coalescingInterval: 1)
    var first = fixture.top.transform
    first.positionX = 0.6
    var second = first
    second.positionX = 0.8
    let key = "layer.\(fixture.top.id.rawValue).transform.position"

    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000109",
        timestamp: 20,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, value: first)
    ))
    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000110",
        timestamp: 20.2,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, value: second)
    ))
    #expect(session.undoCount == 1)
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000111"),
        timestamp: Date(timeIntervalSince1970: 21)
    )
    #expect(session.document.layer(id: fixture.top.id)?.transform == fixture.top.transform)
}

@Test("Composition and layer navigation persists without entering history or clearing Redo")
func navigationDoesNotMutateHistory() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000112",
        timestamp: 22,
        payload: .renameLayer(id: fixture.top.id, to: "Renamed")
    ))
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000113"),
        timestamp: Date(timeIntervalSince1970: 23)
    )
    #expect(session.canRedo)
    let undoCount = session.undoCount
    let redoCount = session.redoCount

    try session.setActiveComposition(fixture.composition.id, timestamp: Date(timeIntervalSince1970: 24))
    try session.setSelectedLayer(fixture.bottom.id, timestamp: Date(timeIntervalSince1970: 25))
    try session.setSelectedMedia(fixture.document.selectedMediaID, timestamp: Date(timeIntervalSince1970: 26))

    #expect(session.document.selectedLayerID == fixture.bottom.id)
    #expect(session.undoCount == undoCount)
    #expect(session.redoCount == redoCount)
    #expect(session.canRedo)
}

@Test("Composition duplication derives owned layer IDs and Undo removes the exact copy")
func duplicateCompositionUsesRequestedIdentities() throws {
    let fixture = try makeLayerCommandFixture()
    let duplicateCompositionID = VertexID(rawValue: "62000000-0000-0000-0000-000000000050")
    let duplicateLayerIDs = [
        VertexID(rawValue: "62000000-0000-0000-0000-000000000051"),
        VertexID(rawValue: "62000000-0000-0000-0000-000000000052")
    ]
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        for: session.document,
        id: "62000000-0000-0000-0000-000000000114",
        timestamp: 27,
        payload: .duplicateComposition(
            sourceID: fixture.composition.id,
            newCompositionID: duplicateCompositionID,
            newLayerIDs: duplicateLayerIDs
        )
    ))

    let duplicate = try #require(session.document.composition(id: duplicateCompositionID))
    #expect(duplicate.layerIDs == duplicateLayerIDs)
    #expect(session.document.layers(in: duplicateCompositionID).map(\.id) == duplicateLayerIDs)
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000115"),
        timestamp: Date(timeIntervalSince1970: 28)
    )
    #expect(session.document.composition(id: duplicateCompositionID) == nil)
    #expect(duplicateLayerIDs.allSatisfy { session.document.layer(id: $0) == nil })
}
