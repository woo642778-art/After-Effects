from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Tests/VertexTimelineTests/TimelineEngineTests.swift"
text = path.read_text()
marker = '''@Test("Invalid trims are rejected rather than clamped")\n'''
addition = r'''@Test("Moving a layer shifts its attached animation keyframes")
func moveShiftsLayerAnimationKeyframes() throws {
    var fixture = try makeFixture([("Animated", 0, 0, 6, 0)])
    var animated = fixture.layers[0]
    animated.animationChannels = [
        ProjectAnimationChannel(
            property: .layer(.opacity),
            keyframes: [
                ProjectKeyframe(time: RationalTime(value: 1, timescale: 1), value: .scalar(0.25), interpolation: .linear),
                ProjectKeyframe(time: RationalTime(value: 3, timescale: 1), value: .scalar(0.75), interpolation: .linear)
            ]
        )
    ]
    fixture.layers[0] = animated
    fixture.project.layerRegistry[0] = animated
    fixture.project = try fixture.project.validated()

    let result = try TimelineEngine().apply(
        .move(layerIDs: [animated.id], delta: RationalTime(value: 2, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    let moved = try layer(animated.id, in: result)
    let channel = try #require(moved.animationChannels.first)
    #expect(channel.keyframes.map(\.time) == [
        RationalTime(value: 3, timescale: 1),
        RationalTime(value: 5, timescale: 1)
    ])
}

'''
if addition not in text:
    if marker not in text:
        raise RuntimeError("Timeline test insertion marker not found")
    text = text.replace(marker, addition + marker, 1)
path.write_text(text)
print("Task 2 review RED test applied")
