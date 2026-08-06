import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("A command increments revision exactly once and is idempotent")
func commandRevisionAndIdentity() throws {
    let project = try ProjectDocument.makeNew(name: "Command", timestamp: Date(timeIntervalSince1970: 1_700_000_000))
    let record = ProjectCommandRecord.settingExposure(
        project: project,
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000020"),
        from: 0,
        to: 1.25,
        timestamp: Date(timeIntervalSince1970: 1_700_000_001)
    )
    let changed = try ProjectCommandEngine().apply(record, to: project)
    #expect(changed.revision == project.revision + 1)
    #expect(changed.renderSettings.exposure == 1.25)
    #expect(throws: ProjectError.self) { try ProjectCommandEngine().apply(record, to: changed) }
}

@Test("Stale base revisions are rejected")
func staleRevisionIsRejected() throws {
    var project = try ProjectDocument.makeNew(name: "Stale")
    project.revision = 4
    let record = ProjectCommandRecord(
        commandID: VertexID(rawValue: "50000000-0000-0000-0000-000000000021"),
        projectID: project.projectID,
        baseRevision: 3,
        timestamp: Date(timeIntervalSince1970: 20),
        mergeKey: nil,
        forwardOperation: .renameProject(before: "Stale", after: "Changed"),
        inverseOperation: .renameProject(before: "Changed", after: "Stale")
    )
    #expect(throws: ProjectError.self) { try ProjectCommandEngine().apply(record, to: project) }
}

@Test("Undo and redo restore render settings")
func undoRedoRoundTrip() throws {
    let controller = try ProjectHistoryController(project: .makeNew(name: "History"))
    try controller.perform(.setRenderParameter(.exposure, before: 0, after: 2), mergeKey: "render.exposure")
    #expect(controller.project.renderSettings.exposure == 2)
    #expect(controller.canUndo)
    try controller.undo()
    #expect(controller.project.renderSettings.exposure == 0)
    #expect(controller.canRedo)
    try controller.redo()
    #expect(controller.project.renderSettings.exposure == 2)
}

@Test("Slider commands coalesce into one undo entry")
func sliderCommandsCoalesce() throws {
    let controller = try ProjectHistoryController(project: .makeNew(name: "Coalesce"), coalescingInterval: 0.5)
    try controller.perform(.setRenderParameter(.exposure, before: 0, after: 0.4), mergeKey: "render.exposure", timestamp: Date(timeIntervalSince1970: 10))
    try controller.perform(.setRenderParameter(.exposure, before: 0.4, after: 1.2), mergeKey: "render.exposure", timestamp: Date(timeIntervalSince1970: 10.2))
    #expect(controller.undoCount == 1)
    try controller.undo()
    #expect(controller.project.renderSettings.exposure == 0)
}

@Test("A new command clears redo history")
func newCommandClearsRedo() throws {
    let controller = try ProjectHistoryController(project: .makeNew(name: "Redo"))
    try controller.perform(.setRenderParameter(.exposure, before: 0, after: 1))
    try controller.undo()
    #expect(controller.canRedo)
    try controller.perform(.setRenderParameter(.saturation, before: 1, after: 2))
    #expect(!controller.canRedo)
}
