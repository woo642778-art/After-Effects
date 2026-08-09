import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func commandTimelineProject() throws -> ProjectDocument {
    var project = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_300_000),
        media: []
    )
    let compositionID = try #require(project.activeCompositionID)
    var composition = try #require(project.composition(id: compositionID))
    let media = MediaReference.fixture(
        id: "94000000-0000-0000-0000-000000000001",
        name: "clip.mov"
    )
    let layer = ProjectLayer(
        id: VertexID(rawValue: "94000000-0000-0000-0000-000000000010"),
        compositionID: compositionID,
        name: "Clip",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 8, timescale: 1))
    )
    composition.layerIDs = [layer.id]
    project.mediaRegistry = [media]
    project.compositionRegistry = [composition]
    project.layerRegistry = [layer]
    project.selectedLayerID = layer.id
    return try project.validated()
}

private func timelineRequest(
    session: ProjectEditingSession,
    payload: ProjectCommandPayload,
    mergeKey: String? = nil
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        projectID: session.document.projectID,
        baseRevision: session.document.revision,
        timestamp: Date(timeIntervalSince1970: 1_700_300_000),
        mergeKey: mergeKey,
        payload: payload
    )
}

@Test("Split timeline mutation is atomic and undo restores layer/order/selection")
func splitTimelineCommandUndoRestoresSemanticState() throws {
    let before = try commandTimelineProject()
    let compositionID = try #require(before.activeCompositionID)
    let original = try #require(before.layerRegistry.first)
    var left = original
    left.timing.outPoint = RationalTime(value: 4, timescale: 1)
    var right = original
    right.id = VertexID(rawValue: "94000000-0000-0000-0000-000000000011")
    right.timing.startTime = RationalTime(value: 4, timescale: 1)
    right.timing.inPoint = RationalTime(value: 4, timescale: 1)
    right.timing.sourceOffset = RationalTime(value: 4, timescale: 1)

    let mutation = TimelineProjectMutation(
        beforeLayers: [original],
        afterLayers: [left, right],
        beforeLayerOrder: [original.id],
        afterLayerOrder: [original.id, right.id],
        beforeSelectedLayerID: original.id,
        afterSelectedLayerID: right.id
    )
    var session = try ProjectEditingSession(document: before)
    _ = try session.apply(timelineRequest(
        session: session,
        payload: .applyTimelineEdit(compositionID: compositionID, result: mutation)
    ))
    #expect(session.document.layers(in: compositionID) == [left, right])
    #expect(session.document.selectedLayerID == right.id)
    #expect(session.undoCount == 1)

    _ = try session.undo(
        commandID: VertexID(rawValue: "94000000-0000-0000-0000-000000000099"),
        timestamp: Date(timeIntervalSince1970: 1_700_300_001)
    )
    #expect(session.document.layers(in: compositionID) == [original])
    #expect(session.document.composition(id: compositionID)?.layerIDs == [original.id])
    #expect(session.document.selectedLayerID == original.id)
}

@Test("Grouped move commits as one reversible project transition")
func groupedTimelineMoveIsOneUndoableCommand() throws {
    let before = try commandTimelineProject()
    let compositionID = try #require(before.activeCompositionID)
    let original = try #require(before.layerRegistry.first)
    var moved = original
    moved.timing.startTime = RationalTime(value: 1, timescale: 1)
    moved.timing.inPoint = RationalTime(value: 1, timescale: 1)
    moved.timing.outPoint = RationalTime(value: 9, timescale: 1)
    let mutation = TimelineProjectMutation(
        beforeLayers: [original],
        afterLayers: [moved],
        beforeLayerOrder: [original.id],
        afterLayerOrder: [original.id],
        beforeSelectedLayerID: original.id,
        afterSelectedLayerID: original.id
    )
    var session = try ProjectEditingSession(document: before)
    _ = try session.apply(timelineRequest(
        session: session,
        payload: .applyTimelineEdit(compositionID: compositionID, result: mutation),
        mergeKey: "timeline.move.\(original.id.rawValue)"
    ))
    #expect(session.undoCount == 1)
    #expect(session.document.layer(id: original.id)?.timing == moved.timing)
}

@Test("Work area parent and layer markers are validated project commands")
func timelineMetadataCommandsAreRealProjectMutations() throws {
    let before = try commandTimelineProject()
    let compositionID = try #require(before.activeCompositionID)
    let layer = try #require(before.layerRegistry.first)
    let marker = ProjectMarker(time: RationalTime(value: 2, timescale: 1), name: "Beat")
    let engine = ProjectCommandEngine()

    let workArea = ProjectWorkArea(start: RationalTime(value: 1, timescale: 1), end: RationalTime(value: 6, timescale: 1))
    let workTransition = try engine.prepare(
        ProjectCommandRequest(projectID: before.projectID, baseRevision: before.revision, payload: .setCompositionWorkArea(id: compositionID, workArea: workArea)),
        for: before
    )
    let withWorkArea = try engine.apply(workTransition, to: before)
    #expect(withWorkArea.composition(id: compositionID)?.workArea == workArea)

    let markerTransition = try engine.prepare(
        ProjectCommandRequest(projectID: withWorkArea.projectID, baseRevision: withWorkArea.revision, payload: .setLayerMarkers(id: layer.id, markers: [marker])),
        for: withWorkArea
    )
    let withMarker = try engine.apply(markerTransition, to: withWorkArea)
    #expect(withMarker.layer(id: layer.id)?.markers == [marker])
}
