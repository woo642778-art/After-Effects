import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

private actor EffectTestFrameResolver: CompositionFrameResolver {
    let image: PortableImage
    private(set) var times: [RationalTime] = []

    init() throws {
        image = try PortableImage(data: Data([1]), format: .png, pixelSize: VertexSize(width: 16, height: 16))
    }

    func resolve(mediaID: VertexID, exactSourceTime: RationalTime, targetSize: VertexSize) async throws -> CompositionFrameResolution {
        times.append(exactSourceTime)
        return .frame(image)
    }

    func requestedTimes() -> [RationalTime] { times }
}

private actor RecordingEffectResolver: CompositionEffectResolver {
    private(set) var requests: [CompositionEffectRequest] = []
    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage {
        requests.append(request)
        return request.input
    }
    func effectTypes() -> [ProjectEffectType] { requests.map(\.effect.type) }
    func effects() -> [ProjectEffect] { requests.map(\.effect) }
}

private func effectFixture(
    effects: [ProjectEffect],
    sourceOffset: RationalTime = .zero,
    masks: [ProjectMask] = [],
    trackMatte: ProjectTrackMatte? = nil
) throws -> (ProjectDocument, ProjectComposition, ProjectLayer) {
    var project = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_400_000),
        media: []
    )
    let media = MediaReference.fixture(id: "96000000-0000-0000-0000-000000000010")
    project.mediaRegistry = [media]
    var composition = project.compositionRegistry[0]
    composition.width = 16
    composition.height = 16
    let layer = ProjectLayer(
        id: VertexID(rawValue: "96000000-0000-0000-0000-000000000020"),
        compositionID: composition.id,
        name: "Layer",
        source: .media(mediaID: media.id, sourceStartTime: RationalTime(value: 1, timescale: 1)),
        timing: LayerTiming(
            startTime: RationalTime(value: 2, timescale: 1),
            inPoint: RationalTime(value: 2, timescale: 1),
            outPoint: RationalTime(value: 9, timescale: 1),
            sourceOffset: sourceOffset
        ),
        effects: effects,
        masks: masks,
        trackMatte: trackMatte
    )
    composition.layerIDs = [layer.id]
    project.compositionRegistry = [composition]
    project.activeCompositionID = composition.id
    project.layerRegistry = [layer]
    return (try project.validated(), composition, layer)
}

private func effectRequest(_ fixture: (ProjectDocument, ProjectComposition, ProjectLayer), at time: RationalTime = RationalTime(value: 3, timescale: 1)) throws -> CompositionRenderRequest {
    CompositionRenderRequest(
        project: fixture.0,
        compositionID: fixture.1.id,
        time: time,
        output: try RenderOutputSpecification(width: 16, height: 16),
        purpose: .interactivePreview
    )
}

@Test("Enabled layer effects evaluate in declared order and disabled effects are skipped")
func effectsEvaluateInDeclaredOrder() async throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    var cutout = ProjectEffect.makeDefault(.cutout); cutout.enabled = false
    let restore = ProjectEffect.makeDefault(.restore)
    let fixture = try effectFixture(effects: [depth, cutout, restore])
    let frames = try EffectTestFrameResolver()
    let effects = RecordingEffectResolver()
    _ = try await CompositionGraphCompiler().compile(
        effectRequest(fixture), resolver: frames, effectResolver: effects,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await effects.effectTypes() == [.depthMap, .restore])
}

@Test("Effect parameter animation is evaluated at exact composition time")
func effectParameterAnimationUsesExactTime() async throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    var fixture = try effectFixture(effects: [depth])
    var layer = fixture.2
    layer.animationChannels = [
        ProjectAnimationChannel(
            property: .effect(effectID: depth.id, parameterID: DepthMapParameterID.smoothing, valueKind: .scalar),
            keyframes: [
                ProjectKeyframe(time: RationalTime(value: 2, timescale: 1), value: .scalar(0), interpolation: .linear),
                ProjectKeyframe(time: RationalTime(value: 4, timescale: 1), value: .scalar(1), interpolation: .linear)
            ]
        )
    ]
    fixture.0.layerRegistry = [layer]
    fixture.0 = try fixture.0.validated()
    let frames = try EffectTestFrameResolver()
    let effects = RecordingEffectResolver()
    _ = try await CompositionGraphCompiler().compile(
        effectRequest(fixture, at: RationalTime(value: 3, timescale: 1)), resolver: frames, effectResolver: effects,
        cancellationToken: RenderCancellationToken()
    )
    let recordedEffects = await effects.effects()
    let evaluated = try #require(recordedEffects.first)
    #expect(evaluated.parameter(id: DepthMapParameterID.smoothing)?.value == .scalar(0.5))
}

@Test("Layer source offset participates in decoded source time")
func sourceOffsetChangesResolvedFrameTime() async throws {
    let fixture = try effectFixture(effects: [], sourceOffset: RationalTime(value: 4, timescale: 1))
    let frames = try EffectTestFrameResolver()
    _ = try await CompositionGraphCompiler().compile(
        effectRequest(fixture, at: RationalTime(value: 3, timescale: 1)), resolver: frames,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await frames.requestedTimes() == [RationalTime(value: 6, timescale: 1)])
}

@Test("Effects are resolved before masks and transform graph nodes")
func effectsResolveBeforeMaskAndTransform() async throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    let mask = ProjectMask(name: "Mask", path: .rectangle(x: 0.1, y: 0.1, width: 0.8, height: 0.8))
    let fixture = try effectFixture(effects: [depth], masks: [mask])
    let frames = try EffectTestFrameResolver()
    let effects = RecordingEffectResolver()
    let rendered = try await CompositionGraphCompiler().compile(
        effectRequest(fixture), resolver: frames, effectResolver: effects,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await effects.effectTypes() == [.depthMap])
    let nodes = try rendered.graph.evaluationPlan().orderedNodes
    let sourceIndex = try #require(nodes.firstIndex { if case .source = $0.kind { return true }; return false })
    let maskIndex = try #require(nodes.firstIndex { if case .mask = $0.kind { return true }; return false })
    let operationsIndex = try #require(nodes.firstIndex { if case .operations = $0.kind { return true }; return false })
    #expect(sourceIndex < maskIndex)
    #expect(maskIndex < operationsIndex)
}

@Test("Removing the effect restores the pre-effect resolver path")
func deletingEffectStopsEffectResolution() async throws {
    let depth = ProjectEffect.makeDefault(.depthMap)
    let withEffect = try effectFixture(effects: [depth])
    var withoutProject = withEffect.0
    var withoutLayer = withEffect.2; withoutLayer.effects = []
    withoutProject.layerRegistry = [withoutLayer]
    withoutProject = try withoutProject.validated()
    let without = (withoutProject, withEffect.1, withoutLayer)
    let framesA = try EffectTestFrameResolver(), framesB = try EffectTestFrameResolver()
    let resolverA = RecordingEffectResolver(), resolverB = RecordingEffectResolver()
    let a = try await CompositionGraphCompiler().compile(effectRequest(withEffect), resolver: framesA, effectResolver: resolverA, cancellationToken: RenderCancellationToken())
    let b = try await CompositionGraphCompiler().compile(effectRequest(without), resolver: framesB, effectResolver: resolverB, cancellationToken: RenderCancellationToken())
    let withTypes = await resolverA.effectTypes()
    let withoutTypes = await resolverB.effectTypes()
    #expect(withTypes == [.depthMap])
    #expect(withoutTypes.isEmpty)
    #expect(a.graph.nodes.map(\.kind).count == b.graph.nodes.map(\.kind).count)
}
