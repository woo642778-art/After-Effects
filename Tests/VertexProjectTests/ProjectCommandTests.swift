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
        payload: .setRenderParameter(.exposure, value: 1.25)
    )
    let initialRevision = session.document.revision
    _ = try session.apply(command)
    #expect(session.document.revision == initialRevision + 1)
    #expect(session.document.renderSettings.exposure == 1.25)
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

@Test("Undo and redo restore render settings")
func undoRedoRoundTrip() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "History"))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000022",
        timestamp: 30,
        payload: .setRenderParameter(.exposure, value: 2)
    ))
    #expect(session.document.renderSettings.exposure == 2)
    #expect(session.canUndo)

    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000023"),
        timestamp: Date(timeIntervalSince1970: 31)
    )
    #expect(session.document.renderSettings.exposure == 0)
    #expect(session.canRedo)

    _ = try session.redo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000024"),
        timestamp: Date(timeIntervalSince1970: 32)
    )
    #expect(session.document.renderSettings.exposure == 2)
}

@Test("Slider commands coalesce into one Undo entry")
func sliderCommandsCoalesce() throws {
    var session = try ProjectEditingSession(
        document: .makeNew(name: "Coalesce"),
        coalescingInterval: 0.5
    )
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000025",
        timestamp: 10,
        mergeKey: "render.exposure",
        payload: .setRenderParameter(.exposure, value: 0.4)
    ))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000026",
        timestamp: 10.2,
        mergeKey: "render.exposure",
        payload: .setRenderParameter(.exposure, value: 1.2)
    ))
    #expect(session.undoCount == 1)
    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000027"),
        timestamp: Date(timeIntervalSince1970: 11)
    )
    #expect(session.document.renderSettings.exposure == 0)
}

@Test("A new command clears Redo history")
func newCommandClearsRedo() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Redo"))
    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000028",
        timestamp: 40,
        payload: .setRenderParameter(.exposure, value: 1)
    ))
    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000029"),
        timestamp: Date(timeIntervalSince1970: 41)
    )
    #expect(session.canRedo)

    _ = try session.apply(request(
        for: session,
        id: "50000000-0000-0000-0000-000000000030",
        timestamp: 42,
        payload: .setRenderParameter(.saturation, value: 2)
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
            payload: .setRenderParameter(.exposure, value: Double(index + 1))
        ))
    }

    #expect(session.undoCount == 2)
    #expect(session.recentCommandCount == 3)
}
