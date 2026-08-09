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
    var document = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        media: []
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
    document.activeCompositionID = composition.id
    document.layerRegistry = [top, bottom]
    document.selectedLayerID = top.id
    document.selectedMediaID = media.id
    return LayerCommandFixture(document: try document.validated(), composition: composition, top: top, bottom: bottom)
}

private func request(
    _ session: ProjectEditingSession,
    id: String,
    time: TimeInterval,
    mergeKey: String? = nil,
    payload: ProjectCommandPayload
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        commandID: VertexID(rawValue: id),
        projectID: session.document.projectID,
        baseRevision: session.document.revision,
        timestamp: Date(timeIntervalSince1970: time),
        mergeKey: mergeKey,
        payload: payload
    )
}

@Test("Layer reorder Undo restores exact authoritative Z-order")
func layerReorderUndoRestoresExactOrder() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        session,
        id: "62000000-0000-0000-0000-000000000101",
        time: 1,
        payload: .reorderLayer(id: fixture.bottom.id, toIndex: 0)
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.bottom.id, fixture.top.id])
    _ = try session.undo(commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000102"))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Layer insertion Undo and Redo restore the same identity and index")
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
        session,
        id: "62000000-0000-0000-0000-000000000103",
        time: 2,
        payload: .insertLayer(third, index: 1)
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
    _ = try session.undo(commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000104"))
    #expect(session.document.layer(id: third.id) == nil)
    _ = try session.redo(commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000105"))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
}

@Test("Locked layers reject edits except explicit unlock")
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
            session,
            id: "62000000-0000-0000-0000-000000000106",
            time: 3,
            payload: .setLayerTransform(id: fixture.top.id, transform: changed)
        ))
    }

    _ = try session.apply(request(
        session,
        id: "62000000-0000-0000-0000-000000000107",
        time: 4,
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
        backgroundColor: .transparent,
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
            session,
            id: "62000000-0000-0000-0000-000000000108",
            time: 5,
            payload: .removeComposition(id: child.id)
        ))
    }
}

@Test("Chained transform commands coalesce into one Undo entry")
func layerTransformCommandsCoalesce() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document, coalescingInterval: 1)
    var first = fixture.top.transform
    first.positionX = 0.6
    var second = first
    second.positionX = 0.8
    let key = "layer.\(fixture.top.id.rawValue).transform.position"

    _ = try session.apply(request(
        session,
        id: "62000000-0000-0000-0000-000000000109",
        time: 10,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, transform: first)
    ))
    _ = try session.apply(request(
        session,
        id: "62000000-0000-0000-0000-000000000110",
        time: 10.2,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, transform: second)
    ))
    #expect(session.undoCount == 1)
    _ = try session.undo(commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000111"))
    #expect(session.document.layer(id: fixture.top.id)?.transform == fixture.top.transform)
}

@Test("Navigation persists convenience state without changing Undo or clearing Redo")
func workspaceNavigationDoesNotEnterHistory() throws {
    var fixture = try makeLayerCommandFixture()
    let second = ProjectComposition(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000050"),
        name: "Second",
        width: 640,
        height: 360,
        duration: RationalTime(value: 10, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: []
    )
    fixture.document.compositionRegistry.append(second)
    fixture.document = try fixture.document.validated()
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        session,
        id: "62000000-0000-0000-0000-000000000112",
        time: 20,
        payload: .renameLayer(id: fixture.top.id, to: "Changed")
    ))
    _ = try session.undo(commandID: VertexID(rawValue: "62000000-0000-0000-0000-000000000113"))
    #expect(session.canRedo)
    let undoBefore = session.undoCount
    let redoBefore = session.redoCount
    try session.setActiveComposition(second.id, timestamp: Date(timeIntervalSince1970: 21))
    #expect(session.undoCount == undoBefore)
    #expect(session.redoCount == redoBefore)
    #expect(session.document.activeCompositionID == second.id)
}
