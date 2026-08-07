import Testing
import VertexCore
import VertexProject
@testable import VertexComposition

private func animatedLayer() throws -> ProjectLayer {
    let compositionID = VertexID(rawValue: "83000000-0000-0000-0000-000000000001")
    let maskID = VertexID(rawValue: "83000000-0000-0000-0000-000000000002")
    let key0 = RationalTime(value: 0, timescale: 30)
    let key30 = RationalTime(value: 30, timescale: 30)
    return ProjectLayer(
        id: VertexID(rawValue: "83000000-0000-0000-0000-000000000003"),
        compositionID: compositionID,
        name: "Animated",
        source: .null,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1)),
        animationChannels: [
            ProjectAnimationChannel(
                id: VertexID(rawValue: "83000000-0000-0000-0000-000000000010"),
                property: .layer(.positionX),
                keyframes: [
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000011"), time: key0, value: .scalar(0.2), interpolation: .linear),
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000012"), time: key30, value: .scalar(0.8), interpolation: .linear)
                ]
            ),
            ProjectAnimationChannel(
                id: VertexID(rawValue: "83000000-0000-0000-0000-000000000020"),
                property: .layer(.opacity),
                keyframes: [
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000021"), time: key0, value: .scalar(0.25), interpolation: .linear),
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000022"), time: key30, value: .scalar(0.75), interpolation: .linear)
                ]
            ),
            ProjectAnimationChannel(
                id: VertexID(rawValue: "83000000-0000-0000-0000-000000000030"),
                property: .mask(maskID: maskID, property: .expansion),
                keyframes: [
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000031"), time: key0, value: .scalar(0), interpolation: .linear),
                    ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000032"), time: key30, value: .scalar(20), interpolation: .linear)
                ]
            )
        ],
        masks: [
            ProjectMask(
                id: maskID,
                name: "Mask",
                path: .rectangle(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
            )
        ]
    )
}

@Test("Layer animation evaluator resolves transform opacity and mask at the same exact time")
func evaluateLayerMotionAndMaskAtExactTime() throws {
    let layer = try animatedLayer()
    let state = try LayerAnimationEvaluator.evaluate(
        layer: layer,
        at: RationalTime(value: 15, timescale: 30)
    )
    #expect(abs(state.transform.positionX - 0.5) < 0.000_001)
    #expect(abs(state.transform.opacity - 0.5) < 0.000_001)
    #expect(abs(state.masks[0].expansionPixels - 10) < 0.000_001)
}

@Test("Layer animation evaluator preserves static fields without channels")
func evaluateLayerMotionStaticFallback() throws {
    var layer = try animatedLayer()
    layer.animationChannels = []
    layer.transform.positionX = 0.37
    layer.masks[0].featherPixels = 7
    let state = try LayerAnimationEvaluator.evaluate(layer: layer, at: RationalTime(value: 20, timescale: 30))
    #expect(state.transform.positionX == 0.37)
    #expect(state.masks[0].featherPixels == 7)
}

@Test("Layer animation evaluator rejects invalid evaluated scale")
func evaluateLayerMotionRejectsInvalidScale() throws {
    var layer = try animatedLayer()
    layer.animationChannels = [
        ProjectAnimationChannel(
            id: VertexID(rawValue: "83000000-0000-0000-0000-000000000040"),
            property: .layer(.scaleX),
            keyframes: [
                ProjectKeyframe(id: VertexID(rawValue: "83000000-0000-0000-0000-000000000041"), time: .zero, value: .scalar(-1), interpolation: .hold)
            ]
        )
    ]
    #expect(throws: ProjectError.self) {
        try LayerAnimationEvaluator.evaluate(layer: layer, at: .zero)
    }
}
