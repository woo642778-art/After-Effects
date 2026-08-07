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

private func makeLayerCommandFixture(topLocked: Bool = false) throws -> LayerCommandFixture {
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
        enabled: true,
        locked: topLocked,
        solo: false,
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
    suffix: String,
    timestamp: TimeInterval,
    mergeKey: String? = nil,
    payload: ProjectCommandPayload
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-\(suffix)"),
        projectID: document.projectID,
        baseRevision: document.revision,
        timestamp: Date(timeIntervalSince1970: timestamp),
        mergeKey: mergeKey,
        payload: payload
    )
}

@Test("Desired-state reorder Undo and Redo restore exact authoritative Z-order")
func desiredStateLayerReorderRoundTrips() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document)
    _ = try session.apply(request(
        for: session.document,
        suffix: "000000000101",
        timestamp: 10,
        payload: .reorderLayer(
            compositionID: fixture.composition.id,
            layerID: fixture.bottom.id,
            toIndex: 0
        )
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.bottom.id, fixture.top.id])

    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000102"),
        timestamp: Date(timeIntervalSince1970: 11)
    )
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])

    _ = try session.redo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000103"),
        timestamp: Date(timeIntervalSince1970: 12)
    )
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs == [fixture.bottom.id, fixture.top.id])
}

@Test("Desired-state insertion derives the exact inverse identity and index")
func desiredStateLayerInsertionRoundTrips() throws {
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
        suffix: "000000000111",
        timestamp: 20,
        payload: .insertLayer(third, compositionID: fixture.composition.id, index: 1)
    ))
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)

    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000112"),
        timestamp: Date(timeIntervalSince1970: 21)
    )
    #expect(session.document.layer(id: third.id) == nil)

    _ = try session.redo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000113"),
        timestamp: Date(timeIntervalSince1970: 22)
    )
    #expect(session.document.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
}

@Test("Locked layers reject edits except an explicit unlock request")
func desiredStateLockedLayerPreconditions() throws {
    let fixture = try makeLayerCommandFixture(topLocked: true)
    var session = try ProjectEditingSession(document: fixture.document)
    var moved = fixture.top.transform
    moved.positionX = 0.75

    #expect(throws: ProjectError.self) {
        try session.apply(request(
            for: session.document,
            suffix: "000000000121",
            timestamp: 30,
            payload: .setLayerTransform(id: fixture.top.id, value: moved)
        ))
    }

    _ = try session.apply(request(
        for: session.document,
        suffix: "000000000122",
        timestamp: 31,
        payload: .setLayerLocked(id: fixture.top.id, value: false)
    ))
    #expect(session.document.layer(id: fixture.top.id)?.locked == false)
}

@Test("Transform requests coalesce while preserving exact Undo state")
func desiredStateTransformCoalescing() throws {
    let fixture = try makeLayerCommandFixture()
    var session = try ProjectEditingSession(document: fixture.document, coalescingInterval: 1)
    var first = fixture.top.transform
    first.positionX = 0.6
    var second = first
    second.positionX = 0.8
    let key = "layer.\(fixture.top.id.rawValue).transform.position"

    _ = try session.apply(request(
        for: session.document,
        suffix: "000000000131",
        timestamp: 40,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, value: first)
    ))
    _ = try session.apply(request(
        for: session.document,
        suffix: "000000000132",
        timestamp: 40.2,
        mergeKey: key,
        payload: .setLayerTransform(id: fixture.top.id, value: second)
    ))
    #expect(session.undoCount == 1)

    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000133"),
        timestamp: Date(timeIntervalSince1970: 41)
    )
    #expect(session.document.layer(id: fixture.top.id)?.transform == fixture.top.transform)
}

@Test("Active composition and selected layer navigation persist without touching Undo Redo")
func navigationDoesNotPolluteHistory() throws {
    let fixture = try makeLayerCommandFixture()
    let secondComposition = ProjectComposition(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000040"),
        name: "Second",
        width: 640,
        height: 360,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: []
    )
    var document = fixture.document
    document.compositionRegistry.append(secondComposition)
    var session = try ProjectEditingSession(document: try document.validated())

    _ = try session.apply(request(
        for: session.document,
        suffix: "000000000141",
        timestamp: 50,
        payload: .renameLayer(id: fixture.top.id, to: "Renamed")
    ))
    _ = try session.undo(
        commandID: VertexID(rawValue: "62000000-0000-0000-0001-000000000142"),
        timestamp: Date(timeIntervalSince1970: 51)
    )
    #expect(session.canRedo)
    let undoCount = session.undoCount
    let redoCount = session.redoCount

    try session.setActiveComposition(secondComposition.id, timestamp: Date(timeIntervalSince1970: 52))
    #expect(session.document.activeCompositionID == secondComposition.id)
    #expect(session.document.selectedLayerID == nil)
    #expect(session.undoCount == undoCount)
    #expect(session.redoCount == redoCount)

    try session.setActiveComposition(fixture.composition.id, timestamp: Date(timeIntervalSince1970: 53))
    try session.setSelectedLayer(fixture.bottom.id, timestamp: Date(timeIntervalSince1970: 54))
    #expect(session.document.selectedLayerID == fixture.bottom.id)
    #expect(session.undoCount == undoCount)
    #expect(session.redoCount == redoCount)
}

@Test("A composition referenced by another composition cannot be removed")
func desiredStateReferencedCompositionCannotBeRemoved() throws {
    var fixture = try makeLayerCommandFixture()
    let child = ProjectComposition(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000050"),
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
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000051"),
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
            suffix: "000000000151",
            timestamp: 60,
            payload: .removeComposition(id: child.id)
        ))
    }
}
