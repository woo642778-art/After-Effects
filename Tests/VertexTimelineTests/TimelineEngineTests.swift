import Testing
import VertexCore
import VertexProject
@testable import VertexTimeline

private struct TimelineFixture {
    var project: ProjectDocument
    var composition: ProjectComposition
    var layers: [ProjectLayer]
}

private func makeFixture(_ ranges: [(String, Int64, Int64, Int64, Int64)]) throws -> TimelineFixture {
    var project = try ProjectDocument.makeNew(name: "Timeline")
    let compositionID = try #require(project.activeCompositionID)
    var composition = try #require(project.composition(id: compositionID))
    var layers: [ProjectLayer] = []
    var media: [MediaReference] = []

    for (index, item) in ranges.enumerated() {
        let mediaID = VertexID(rawValue: String(format: "92000000-0000-0000-0000-%012d", index + 1))
        let layerID = VertexID(rawValue: String(format: "92100000-0000-0000-0000-%012d", index + 1))
        media.append(MediaReference.fixture(id: mediaID.rawValue, name: "\(item.0).mov"))
        layers.append(ProjectLayer(
            id: layerID,
            compositionID: compositionID,
            name: item.0,
            source: .media(mediaID: mediaID, sourceStartTime: .zero),
            timing: LayerTiming(
                startTime: RationalTime(value: item.1, timescale: 1),
                inPoint: RationalTime(value: item.2, timescale: 1),
                outPoint: RationalTime(value: item.3, timescale: 1),
                sourceOffset: RationalTime(value: item.4, timescale: 1)
            )
        ))
    }
    project.mediaRegistry = media
    project.layerRegistry = layers
    composition.layerIDs = layers.map(\.id)
    project.compositionRegistry = [composition]
    project = try project.validated()
    return TimelineFixture(project: project, composition: composition, layers: layers)
}

private func layer(_ id: VertexID, in result: TimelineEditResult) throws -> ProjectLayer {
    try #require(result.updatedLayers.first(where: { $0.id == id }))
}

@Test("Split preserves source continuity and layer order")
func splitPreservesSourceContinuity() throws {
    let fixture = try makeFixture([("Clip", 0, 0, 10, 2)])
    let source = fixture.layers[0]
    let result = try TimelineEngine().apply(
        .split(layerID: source.id, at: RationalTime(value: 4, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    let left = try layer(source.id, in: result)
    let right = try #require(result.insertedLayers.first)
    #expect(left.timing.outPoint == RationalTime(value: 4, timescale: 1))
    #expect(right.timing.startTime == RationalTime(value: 4, timescale: 1))
    #expect(right.timing.inPoint == RationalTime(value: 4, timescale: 1))
    #expect(right.timing.outPoint == RationalTime(value: 10, timescale: 1))
    #expect(right.timing.sourceOffset == RationalTime(value: 6, timescale: 1))
    #expect(result.resultingLayerOrder == [source.id, right.id])
}

@Test("Normal move never ripples unrelated layers")
func moveDoesNotRippleUnrelatedLayers() throws {
    let fixture = try makeFixture([("A", 0, 0, 2, 0), ("B", 3, 3, 5, 0)])
    let a = fixture.layers[0]
    let b = fixture.layers[1]
    let result = try TimelineEngine().apply(
        .move(layerIDs: [a.id], delta: RationalTime(value: 1, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    let moved = try layer(a.id, in: result)
    #expect(moved.timing.inPoint == RationalTime(value: 1, timescale: 1))
    #expect(result.updatedLayers.contains(where: { $0.id == b.id }) == false)
}

@Test("Moving a layer shifts its attached animation keyframes")
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

@Test("Invalid trims are rejected rather than clamped")
func invalidTrimIsRejected() throws {
    let fixture = try makeFixture([("Clip", 0, 1, 5, 0)])
    let id = fixture.layers[0].id
    #expect(throws: ProjectError.self) {
        _ = try TimelineEngine().apply(
            .trimOut(layerID: id, to: RationalTime(value: 1, timescale: 1)),
            to: fixture.project,
            compositionID: fixture.composition.id
        )
    }
}

@Test("Ripple shifts only explicitly named affected layers")
func rippleMovesOnlyExplicitScope() throws {
    let fixture = try makeFixture([("A", 0, 0, 2, 0), ("B", 2, 2, 4, 0), ("C", 5, 5, 7, 0)])
    let a = fixture.layers[0], b = fixture.layers[1], c = fixture.layers[2]
    let result = try TimelineEngine().apply(
        .ripple(
            layerID: a.id,
            edge: .out,
            to: RationalTime(value: 3, timescale: 1),
            affectedLayerIDs: [b.id]
        ),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    #expect(try layer(a.id, in: result).timing.outPoint == RationalTime(value: 3, timescale: 1))
    #expect(try layer(b.id, in: result).timing.inPoint == RationalTime(value: 3, timescale: 1))
    #expect(result.updatedLayers.contains(where: { $0.id == c.id }) == false)
}

@Test("Roll moves shared boundary while preserving outer interval")
func rollPreservesOuterInterval() throws {
    let fixture = try makeFixture([("Left", 0, 0, 4, 0), ("Right", 4, 4, 8, 0)])
    let left = fixture.layers[0], right = fixture.layers[1]
    let result = try TimelineEngine().apply(
        .roll(leftLayerID: left.id, rightLayerID: right.id, boundary: RationalTime(value: 5, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    #expect(try layer(left.id, in: result).timing.inPoint == .zero)
    #expect(try layer(left.id, in: result).timing.outPoint == RationalTime(value: 5, timescale: 1))
    #expect(try layer(right.id, in: result).timing.inPoint == RationalTime(value: 5, timescale: 1))
    #expect(try layer(right.id, in: result).timing.outPoint == RationalTime(value: 8, timescale: 1))
}

@Test("Slip changes only source offset")
func slipPreservesCompositionTiming() throws {
    let fixture = try makeFixture([("Clip", 1, 1, 6, 2)])
    let original = fixture.layers[0]
    let result = try TimelineEngine().apply(
        .slip(layerID: original.id, sourceDelta: RationalTime(value: 3, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    let slipped = try layer(original.id, in: result)
    #expect(slipped.timing.startTime == original.timing.startTime)
    #expect(slipped.timing.inPoint == original.timing.inPoint)
    #expect(slipped.timing.outPoint == original.timing.outPoint)
    #expect(slipped.timing.sourceOffset == RationalTime(value: 5, timescale: 1))
}

@Test("Slide preserves selected duration and adjusts adjacent boundaries")
func slidePreservesSelectedDuration() throws {
    let fixture = try makeFixture([("Prev", 0, 0, 2, 0), ("Selected", 2, 2, 4, 0), ("Next", 4, 4, 6, 0)])
    let prev = fixture.layers[0], selected = fixture.layers[1], next = fixture.layers[2]
    let result = try TimelineEngine().apply(
        .slide(
            layerID: selected.id,
            delta: RationalTime(value: 1, timescale: 1),
            previousLayerID: prev.id,
            nextLayerID: next.id
        ),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    let moved = try layer(selected.id, in: result)
    #expect(moved.timing.inPoint == RationalTime(value: 3, timescale: 1))
    #expect(moved.timing.outPoint == RationalTime(value: 5, timescale: 1))
    #expect(try layer(prev.id, in: result).timing.outPoint == RationalTime(value: 3, timescale: 1))
    #expect(try layer(next.id, in: result).timing.inPoint == RationalTime(value: 5, timescale: 1))
}
