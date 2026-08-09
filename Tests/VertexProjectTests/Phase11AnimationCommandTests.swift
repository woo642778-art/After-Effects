import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("Phase 11 animation channel changes are one reversible project command")
func phase11AnimationMotionStateIsAtomic() throws {
    var document = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_500_000),
        media: []
    )
    let composition = try #require(document.compositionRegistry.first)
    let layer = ProjectLayer(
        id: VertexID(rawValue: "c2000000-0000-0000-0000-000000000001"),
        compositionID: composition.id,
        name: "Animated Null",
        source: .null,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    )
    document.layerRegistry = [layer]
    document.compositionRegistry[0].layerIDs = [layer.id]
    document.selectedLayerID = layer.id
    document = try document.validated()

    let channel = ProjectAnimationChannel(
        property: .layer(.opacity),
        keyframes: [
            ProjectKeyframe(time: .zero, value: .scalar(0), interpolation: .linear),
            ProjectKeyframe(time: RationalTime(value: 1, timescale: 1), value: .scalar(1), interpolation: .linear)
        ]
    )
    var session = try ProjectEditingSession(document: document)
    let request = ProjectCommandRequest(
        projectID: session.document.projectID,
        baseRevision: session.document.revision,
        payload: .setLayerMotionState(
            id: layer.id,
            animationChannels: [channel],
            masks: [],
            trackMatte: nil
        )
    )

    _ = try session.apply(request)
    #expect(session.document.layer(id: layer.id)?.animationChannels == [channel])
    #expect(session.undoCount == 1)

    _ = try session.undo()
    #expect(session.document.layer(id: layer.id)?.animationChannels.isEmpty == true)
}
