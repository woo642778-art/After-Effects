import Foundation
import Testing
@testable import VertexProject
import VertexCore

private func request(
    session: ProjectEditingSession,
    id: VertexID = VertexID(),
    timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
    mergeKey: String? = nil,
    payload: ProjectCommandPayload
) -> ProjectCommandRequest {
    ProjectCommandRequest(
        commandID: id,
        projectID: session.document.projectID,
        baseRevision: session.document.revision,
        timestamp: timestamp,
        mergeKey: mergeKey,
        payload: payload
    )
}

@Test("Opening a project session starts with empty Undo Redo and command identity state")
func sessionStartsEmpty() throws {
    let session = try ProjectEditingSession(document: .makeNew(name: "Session"))
    #expect(!session.canUndo)
    #expect(!session.canRedo)
    #expect(session.undoCount == 0)
    #expect(session.redoCount == 0)
    #expect(session.recentCommandCount == 0)
    #expect(!session.hasUnsavedChanges)
}

@Test("Duplicate command IDs are scoped to one active session")
func duplicateCommandIDsAreSessionScoped() throws {
    let commandID = VertexID(rawValue: "52000000-0000-0000-0000-000000000001")
    var first = try ProjectEditingSession(document: .makeNew(name: "First"))
    _ = try first.apply(request(session: first, id: commandID, payload: .renameProject(to: "Changed")))

    #expect(throws: ProjectError.self) {
        try first.apply(request(session: first, id: commandID, payload: .renameProject(to: "Rejected")))
    }

    var reopened = try ProjectEditingSession(document: first.document)
    _ = try reopened.apply(request(session: reopened, id: commandID, payload: .renameProject(to: "Allowed")))
    #expect(reopened.document.metadata.name == "Allowed")
}

@Test("Undo and Redo stacks retain at most two hundred edits")
func historyIsBounded() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "History"))
    for index in 0..<205 {
        _ = try session.apply(
            request(
                session: session,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                payload: .setRenderParameter(.exposure, value: Double(index + 1))
            )
        )
    }
    #expect(session.undoCount == 200)
    #expect(session.redoCount == 0)
}

@Test("Recent command identity tracking retains at most five hundred twelve IDs")
func recentCommandIDsAreBounded() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "IDs"))
    for index in 0..<520 {
        _ = try session.apply(
            request(
                session: session,
                timestamp: Date(timeIntervalSince1970: 1_700_001_000 + Double(index)),
                payload: .setRenderParameter(.exposure, value: Double(index + 1))
            )
        )
    }
    #expect(session.recentCommandCount == 512)
}

@Test("Compatible slider edits coalesce into one Undo transition")
func sessionCoalescesContinuousEdits() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Coalesce"), coalescingInterval: 0.5)
    _ = try session.apply(
        request(
            session: session,
            timestamp: Date(timeIntervalSince1970: 10),
            mergeKey: "render.exposure",
            payload: .setRenderParameter(.exposure, value: 0.4)
        )
    )
    _ = try session.apply(
        request(
            session: session,
            timestamp: Date(timeIntervalSince1970: 10.2),
            mergeKey: "render.exposure",
            payload: .setRenderParameter(.exposure, value: 1.2)
        )
    )
    #expect(session.undoCount == 1)
    _ = try session.undo(
        commandID: VertexID(rawValue: "52000000-0000-0000-0000-000000000010"),
        timestamp: Date(timeIntervalSince1970: 11)
    )
    #expect(session.document.renderSettings.exposure == 0)
}

@Test("Workspace selection does not clear Redo history")
func selectionDoesNotEnterEditHistory() throws {
    var document = try ProjectDocument.makeNew(name: "Selection")
    let media = MediaReference.fixture(
        id: "52000000-0000-0000-0000-000000000020",
        name: "clip.mov"
    )
    document.mediaRegistry = [media]
    document = try document.validated()

    var session = try ProjectEditingSession(document: document)
    _ = try session.apply(request(session: session, payload: .renameProject(to: "Edited")))
    _ = try session.undo(
        commandID: VertexID(rawValue: "52000000-0000-0000-0000-000000000021"),
        timestamp: Date(timeIntervalSince1970: 30)
    )
    #expect(session.canRedo)

    try session.setSelectedMedia(media.id, timestamp: Date(timeIntervalSince1970: 31))
    #expect(session.document.selectedMediaID == media.id)
    #expect(session.canRedo)
    #expect(session.undoCount == 0)
}

@Test("Invalid saved revision leaves session state unchanged")
func failedMarkSavedIsNonMutating() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Save"))
    _ = try session.apply(request(session: session, payload: .renameProject(to: "Dirty")))
    let savedRevision = session.savedRevision
    let undoCount = session.undoCount

    #expect(throws: ProjectError.self) {
        try session.markSaved(revision: session.document.revision + 1)
    }
    #expect(session.savedRevision == savedRevision)
    #expect(session.hasUnsavedChanges)
    #expect(session.undoCount == undoCount)
    #expect(session.document.metadata.name == "Dirty")
}

@Test("Session history never appears in canonical project bytes")
func sessionHistoryIsNotSerialized() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "No History"))
    _ = try session.apply(request(session: session, payload: .renameProject(to: "Changed")))
    let json = String(decoding: try DeterministicProjectCodec().encode(session.document), as: UTF8.self)
    #expect(!json.contains("undo"))
    #expect(!json.contains("redo"))
    #expect(!json.contains("commandID"))
    #expect(!json.contains("inverse"))
}
