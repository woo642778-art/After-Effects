import Foundation
import Testing
@testable import VertexProject
import VertexCore

private func request(
    for session: ProjectEditingSession,
    id: String,
    timestamp: TimeInterval,
    mergeKey: String? = nil,
    payload: ProjectCommandPayload
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        commandID: VertexID(rawValue: id),
        projectID: session.document.projectID,
        baseRevision: session.document.revision,
        timestamp: Date(timeIntervalSince1970: timestamp),
        mergeKey: mergeKey,
        payload: payload
    )
}

private func makeLayerSession(
    name: String,
    coalescingInterval: TimeInterval = 0.5,
    historyLimit: Int = 200,
    recentCommandLimit: Int = 512
) throws -> ProjectEditingSession {
    let projectID = VertexID(rawValue: "50000000-0000-0000-0000-000000000001")
    let mediaID = VertexID(rawValue: "50000000-0000-0000-0000-000000000002")
    let layerID = VertexID(rawValue: "50000000-0000-0000-0000-000000000003")
    var document = try ProjectDocument.makeNew(
        id: projectID,
        name: name,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let media = MediaReference.fixture(id: mediaID.rawValue)
    document.mediaRegistry = [media]
    let compositionID = try #require(document.activeCompositionID)
    let composition = try #require(document.composition(id: compositionID))
    let layer = ProjectLayer(
        id: layerID,
        compositionID: compositionID,
        name: "Clip",
        source: .media(mediaID: mediaID, sourceStartTime: .zero),
        enabled: true,
        locked: false,
        solo: false,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration),
        transform: .identity,
        blendMode: .normal,
        operations: []
    )
    document.layerRegistry = [layer]
    document.compositionRegistry[0].layerIDs = [layerID]
    document.selectedLayerID = layerID
    document.selectedMediaID = mediaID
    return try ProjectEditingSession(
        document: document.validated(),
        coalescingInterval: coalescingInterval,
        historyLimit: historyLimit,
        recentCommandLimit: recentCommandLimit
    )
}

@Test("A session command increments revision exactly once and rejects duplicate IDs")
func commandRevisionAndIdentity() throws {
    var session = try ProjectEditingSession(
        document: .makeNew(
            name: "Command",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    )
    let command = request(
        for: session,
        id: "50000000-0000-0000-0000-000000000020",
        timestamp: 1_700_000_001,
        payload: .renameProject(to: "Command Renamed")
    )
    let initialRevision = session.document.revision
    _ = try session.apply(command)
    #expect(session.document.revision == initialRevision + 1)
    #expect(session.document.metadata.name == "Command Renamed")
    #expect(throws: ProjectError.self) { try session.apply(command) }
}

@Test("Stale base revisions are rejected before mutation")
func staleRevisionIsRejected() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Stale"))
    let stale = ProjectCommandRequest(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000021"),
        projectID: session.document.projectID,
        baseRevision: session.document.revision + 1,
        timestamp: Date(timeIntervalSince1970: 20),
        payload: .renameProject(to: "Changed")
    )
    let before = session.document
    #expect(throws: ProjectError.self) { try session.apply(stale) }
    #expect(session.document == before)
    #expect(!session.canUndo)
}

@Test("Undo and redo restore project edits")
func undoRedoRoundTrip() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "History"))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000022",
        timestamp: 30,
        payload: .renameProject(to: "History Edited")
    ))
    #expect(session.document.metadata.name == "History Edited")
    #expect(session.canUndo)

    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000023"),
        timestamp: Date(timeIntervalSince1970: 31)
    )
    #expect(session.document.metadata.name == "History")
    #expect(session.canRedo)

    _ = try session.redo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000024"),
        timestamp: Date(timeIntervalSince1970: 32)
    )
    #expect(session.document.metadata.name == "History Edited")
}

@Test("Layer transform slider commands coalesce into one Undo entry")
func sliderCommandsCoalesce() throws {
    var session = try makeLayerSession(name: "Coalesce", coalescingInterval: 0.5)
    let layerID = try #require(session.document.selectedLayerID)
    var first = LayerTransform.identity
    first.positionX = 0.6
    var second = first
    second.positionX = 0.8

    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000025",
        timestamp: 10,
        mergeKey: "layer.position.x",
        payload: .setLayerTransform(id: layerID, transform: first)
    ))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000026",
        timestamp: 10.2,
        mergeKey: "layer.position.x",
        payload: .setLayerTransform(id: layerID, transform: second)
    ))
    #expect(session.undoCount == 1)
    #expect(session.document.layer(id: layerID)?.transform.positionX == 0.8)

    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000027"),
        timestamp: Date(timeIntervalSince1970: 11)
    )
    #expect(session.document.layer(id: layerID)?.transform == .identity)
}

@Test("A new command clears Redo history")
func newCommandClearsRedo() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Redo"))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000028",
        timestamp: 40,
        payload: .renameProject(to: "Redo Renamed")
    ))
    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000029"),
        timestamp: Date(timeIntervalSince1970: 41)
    )
    #expect(session.canRedo)

    let compositionID = try #require(session.document.activeCompositionID)
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000030",
        timestamp: 42,
        payload: .setCompositionBackground(
            id: compositionID,
            color: ProjectRGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        )
    ))
    #expect(!session.canRedo)
}

@Test("History and recent command IDs remain bounded")
func sessionBoundsHistoryAndCommandIDs() throws {
    var session = try ProjectEditingSession(
        document: .makeNew(name: "Bounds"),
        historyLimit: 2,
        recentCommandLimit: 3
    )

    for index in 0..<4 {
        _ = try session.apply(request(
            for: session,
            id: String(format: "50000000-0000-0000-0000-%012d", 100 + index),
            timestamp: TimeInterval(100 + index),
            payload: .renameProject(to: "Bounds \(index)")
        ))
    }

    #expect(session.undoCount == 2)
    #expect(session.recentCommandCount == 3)
}