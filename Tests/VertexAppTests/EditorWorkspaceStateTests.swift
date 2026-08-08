import Testing
import VertexCore
import VertexProject
@testable import Vertex

private func workspaceFixture() throws -> ProjectDocument {
    var project = try ProjectDocument.makeNew(name: "Workspace")
    guard let firstID = project.activeCompositionID,
          let firstIndex = project.compositionRegistry.firstIndex(where: { $0.id == firstID }) else {
        throw ProjectError.invalidOperation("Fixture has no active composition")
    }
    let firstComposition = project.compositionRegistry[firstIndex]
    let timing = try LayerTiming(
        startTime: .zero,
        inPoint: .zero,
        outPoint: RationalTime(value: 5, timescale: 1),
        sourceOffset: .zero
    ).validated(for: firstComposition)
    let firstLayer = ProjectLayer(
        compositionID: firstID,
        name: "First",
        source: .null,
        timing: timing
    )
    let secondID = VertexID()
    let second = ProjectComposition(
        id: secondID,
        name: "Second",
        width: 1920,
        height: 1080,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: firstComposition.color,
        backgroundColor: .transparent,
        layerIDs: []
    )
    project.layerRegistry.append(firstLayer)
    project.compositionRegistry[firstIndex].layerIDs = [firstLayer.id]
    project.compositionRegistry.append(second)
    project.selectedLayerID = firstLayer.id
    return try project.validated()
}

@Test("Editor workspace clamps exact playhead to active composition duration")
@MainActor func workspaceClampsPlayhead() throws {
    let project = try workspaceFixture()
    let state = EditorWorkspaceState()
    state.playhead = RationalTime(value: 50, timescale: 1)
    state.synchronize(project: project)
    guard let id = project.activeCompositionID, let composition = project.composition(id: id) else {
        Issue.record("Missing active composition")
        return
    }
    #expect(state.playhead == composition.duration)
}

@Test("Changing active composition removes invalid layer and keyframe selection")
@MainActor func workspaceFiltersSelectionWhenCompositionChanges() throws {
    var project = try workspaceFixture()
    guard let firstLayer = project.layerRegistry.first,
          let second = project.compositionRegistry.last else {
        Issue.record("Fixture incomplete")
        return
    }
    let state = EditorWorkspaceState()
    state.selectedLayerIDs = [firstLayer.id]
    state.selectedKeyframeIDs = [VertexID()]
    state.synchronize(project: project)
    #expect(state.selectedLayerIDs == [firstLayer.id])
    project.activeCompositionID = second.id
    project.selectedLayerID = nil
    state.synchronize(project: project)
    #expect(state.selectedLayerIDs.isEmpty)
    #expect(state.selectedKeyframeIDs.isEmpty)
}

@Test("Presentation-only workspace state never mutates the project document")
@MainActor func workspacePresentationStateIsDocumentNeutral() throws {
    let project = try workspaceFixture()
    let snapshot = project
    let state = EditorWorkspaceState()
    state.synchronize(project: project)
    state.compactPanel = .effects
    state.graphMode = .value
    state.snappingEnabled = false
    state.pixelsPerSecond = 240
    state.activeTool = .slip
    #expect(project == snapshot)
}

@Test("Exact frame selection derives RationalTime from composition frame rate")
@MainActor func workspaceExactFrameTime() throws {
    let project = try workspaceFixture()
    guard let id = project.activeCompositionID, let composition = project.composition(id: id) else {
        Issue.record("Fixture has no active composition")
        return
    }
    let state = EditorWorkspaceState()
    state.setPlayhead(frameIndex: 15, composition: composition)
    #expect(state.playhead == RationalTime(value: 1, timescale: 2))
}
