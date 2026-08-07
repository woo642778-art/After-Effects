import Foundation
import Testing
@testable import VertexProject
import VertexCore

private func commandRequest(
    document: ProjectDocument,
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

@Test("A desired-state command increments revision exactly once")
func commandRevisionAndIdentity() throws {
    let project = try ProjectDocument.makeNew(
        name: "Command",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let request = commandRequest(
        document: project,
        id: "50000000-0000-0000-0000-000000000020",
        timestamp: 1_700_000_001,
        payload: .renameProject(to: "Changed")
    )
    let transition = try ProjectCommandEngine().prepare(request, for: project)
    let changed = try ProjectCommandEngine().apply(transition, to: project)
    #expect(changed.revision == project.revision + 1)
    #expect(changed.metadata.name == "Changed")
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().apply(transition, to: changed)
    }
}

@Test("Stale desired-state base revisions are rejected")
func staleRevisionIsRejected() throws {
    var project = try ProjectDocument.makeNew(name: "Stale")
    project.revision = 4
    let request = ProjectCommandRequest(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000021"),
        projectID: project.projectID,
        baseRevision: 3,
        payload: .renameProject(to: "Changed")
    )
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().prepare(request, for: project)
    }
}

@Test("Prepared transitions derive exact inverse values without mutating input")
func prepareDerivesExactInverse() throws {
    let project = try ProjectDocument.makeNew(name: "Inverse")
    let request = commandRequest(
        document: project,
        id: "50000000-0000-0000-0000-000000000022",
        timestamp: 20,
        payload: .renameProject(to: "After")
    )
    let transition = try ProjectCommandEngine().prepare(request, for: project)
    #expect(project.metadata.name == "Inverse")
    #expect(transition.forward == .renameProject(before: "Inverse", after: "After"))
    #expect(transition.inverse == .renameProject(before: "After", after: "Inverse"))
}

@Test("Session Undo and Redo restore canonical project values")
func undoRedoRoundTrip() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "History"))
    _ = try session.apply(commandRequest(
        document: session.document,
        id: "50000000-0000-0000-0000-000000000023",
        timestamp: 30,
        payload: .renameProject(to: "Edited")
    ))
    #expect(session.document.metadata.name == "Edited")
    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000024"),
        timestamp: Date(timeIntervalSince1970: 31)
    )
    #expect(session.document.metadata.name == "History")
    _ = try session.redo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000025"),
        timestamp: Date(timeIntervalSince1970: 32)
    )
    #expect(session.document.metadata.name == "Edited")
}

@Test("A new session command clears Redo history")
func newCommandClearsRedo() throws {
    var session = try ProjectEditingSession(document: .makeNew(name: "Redo"))
    _ = try session.apply(commandRequest(
        document: session.document,
        id: "50000000-0000-0000-0000-000000000026",
        timestamp: 40,
        payload: .renameProject(to: "First")
    ))
    _ = try session.undo(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000027"),
        timestamp: Date(timeIntervalSince1970: 41)
    )
    #expect(session.canRedo)
    _ = try session.apply(commandRequest(
        document: session.document,
        id: "50000000-0000-0000-0000-000000000028",
        timestamp: 42,
        payload: .renameProject(to: "Second")
    ))
    #expect(!session.canRedo)
}
