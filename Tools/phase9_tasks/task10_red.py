from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
p = ROOT / 'Tests/VertexAppTests/EditorWorkspaceStateTests.swift'
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(r'''import Testing
import VertexCore
import VertexProject
@testable import Vertex

private func workspaceFixture() throws -> ProjectDocument {
    var project = try ProjectDocument.makeNew(displayName: "Workspace")
    guard let firstID = project.activeCompositionID,
          let firstIndex = project.compositionRegistry.firstIndex(where: { $0.id == firstID }) else {
        throw ProjectError.invalidOperation("Fixture has no active composition")
    }
    let timing = try LayerTiming(
        startTime: .zero,
        inPoint: .zero,
        outPoint: RationalTime(value: 5, timescale: 1),
        sourceOffset: .zero
    ).validated()
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
        color: project.compositionRegistry[firstIndex].color,
        backgroundColor: .transparent,
        layerIDs: []
    )
    project.layerRegistry.append(firstLayer)
    project.compositionRegistry[firstIndex].layerIDs = [firstLayer.id]
    project.compositionRegistry.append(second)
    project.selectedLayerID = firstLayer.id
    return project
}

@Test("Editor workspace clamps exact playhead to active composition duration")
@MainActor func workspaceClampsPlayhead() throws {
    let project = try workspaceFixture()
    let state = EditorWorkspaceState()
    state.playhead = RationalTime(value: 50, timescale: 1)
    state.synchronize(project: project)
    #expect(state.playhead == project.activeComposition?.duration)
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
    guard let composition = project.activeComposition else {
        Issue.record("Fixture has no active composition")
        return
    }
    let state = EditorWorkspaceState()
    state.setPlayhead(frameIndex: 15, composition: composition)
    #expect(state.playhead == RationalTime(value: 1, timescale: 2))
}
''')
print('Task 10 RED tests written')
