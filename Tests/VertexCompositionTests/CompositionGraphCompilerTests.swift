import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
import VertexRender

private actor CountingFrameResolver: CompositionFrameResolver {
    private(set) var requests: [(VertexID, RationalTime, VertexSize)] = []
    let result: CompositionFrameResolution

    init(result: CompositionFrameResolution? = nil) throws {
        if let result {
            self.result = result
        } else {
            self.result = .frame(try PortableImage(
                data: Data([1]),
                format: .png,
                pixelSize: VertexSize(width: 16, height: 16)
            ))
        }
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        requests.append((mediaID, exactSourceTime, targetSize))
        return result
    }

    func count() -> Int { requests.count }
    func requestedTimes() -> [RationalTime] { requests.map(\.1) }
}

private struct CompositionFixture {
    var project: ProjectDocument
    var composition: ProjectComposition
    var media: MediaReference
    var top: ProjectLayer
    var bottom: ProjectLayer
}

private func makeCompositionFixture(sameMedia: Bool = true) throws -> CompositionFixture {
    let media = MediaReference.fixture(id: "65000000-0000-0000-0000-000000000010")
    let secondMedia = MediaReference.fixture(id: "65000000-0000-0000-0000-000000000011", name: "second.mov")
    var project = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        media: sameMedia ? [media] : [media, secondMedia]
    )
    var composition = try #require(project.compositionRegistry.first)
    composition.width = 16
    composition.height = 16
    let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    let top = ProjectLayer(
        id: VertexID(rawValue: "65000000-0000-0000-0000-000000000021"),
        compositionID: composition.id,
        name: "Top",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: timing,
        blendMode: .screen
    )
    let bottom = ProjectLayer(
        id: VertexID(rawValue: "65000000-0000-0000-0000-000000000022"),
        compositionID: composition.id,
        name: "Bottom",
        source: .media(mediaID: sameMedia ? media.id : secondMedia.id, sourceStartTime: .zero),
        timing: timing,
        blendMode: .normal
    )
    composition.layerIDs = [top.id, bottom.id]
    project.compositionRegistry = [composition]
    project.layerRegistry = [top, bottom]
    project.selectedLayerID = top.id
    project.selectedMediaID = media.id
    return CompositionFixture(
        project: try project.validated(),
        composition: composition,
        media: media,
        top: top,
        bottom: bottom
    )
}

private func request(for fixture: CompositionFixture, time: RationalTime = .zero) throws -> CompositionRenderRequest {
    CompositionRenderRequest(
        project: fixture.project,
        compositionID: fixture.composition.id,
        time: time,
        output: try RenderOutputSpecification(width: 16, height: 16)
    )
}

@Test("Compiler expands authoritative bottom-to-top Z-order")
func bottomToTopExpansion() async throws {
    let fixture = try makeCompositionFixture(sameMedia: false)
    let resolver = try CountingFrameResolver()
    let rendered = try await CompositionGraphCompiler().compile(
        request(for: fixture),
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    let plan = try rendered.graph.evaluationPlan()
    let composites = plan.orderedNodes.filter {
        if case .composite = $0.kind { return true }
        return false
    }
    #expect(composites.count == 2)
    if case .composite(.normal) = composites[0].kind {} else { Issue.record("Bottom layer must composite first with Normal") }
    if case .composite(.screen) = composites[1].kind {} else { Issue.record("Top layer must composite second with Screen") }
}

@Test("Identical media time and target resolve once per render")
func requestLocalFrameDeduplication() async throws {
    let fixture = try makeCompositionFixture(sameMedia: true)
    let resolver = try CountingFrameResolver()
    _ = try await CompositionGraphCompiler().compile(
        request(for: fixture),
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await resolver.count() == 1)
}

@Test("Disabled and non-Solo layers do not resolve participating media")
func visibilityAndSoloFiltering() async throws {
    var fixture = try makeCompositionFixture(sameMedia: false)
    fixture.top.solo = true
    fixture.project.layerRegistry = [fixture.top, fixture.bottom]
    fixture.project = try fixture.project.validated()
    let resolver = try CountingFrameResolver()
    _ = try await CompositionGraphCompiler().compile(
        request(for: fixture),
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await resolver.count() == 1)
}

@Test("Negative media source time produces transparency without resolving")
func negativeSourceTimeIsTransparent() async throws {
    var fixture = try makeCompositionFixture()
    fixture.top.timing.startTime = RationalTime(value: 5, timescale: 1)
    fixture.bottom.enabled = false
    fixture.project.layerRegistry = [fixture.top, fixture.bottom]
    fixture.project = try fixture.project.validated()
    let resolver = try CountingFrameResolver()
    let result = try await CompositionGraphCompiler().compile(
        request(for: fixture, time: RationalTime(value: 1, timescale: 1)),
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    #expect(await resolver.count() == 0)
    #expect(try result.graph.evaluationPlan().orderedNodes.count == 2)
}

@Test("Adjustment affects the accumulated result before layers above")
func adjustmentPlacement() async throws {
    var fixture = try makeCompositionFixture(sameMedia: false)
    let adjustment = ProjectLayer(
        id: VertexID(rawValue: "65000000-0000-0000-0000-000000000023"),
        compositionID: fixture.composition.id,
        name: "Adjustment",
        source: .adjustment(scope: .belowAll),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: fixture.composition.duration),
        transform: LayerTransform(
            positionX: 0.5, positionY: 0.5, anchorX: 0.5, anchorY: 0.5,
            scaleX: 1, scaleY: 1, rotationDegrees: 0, opacity: 0.5
        ),
        operations: [.exposure(stops: 1)]
    )
    fixture.composition.layerIDs = [fixture.top.id, adjustment.id, fixture.bottom.id]
    fixture.project.compositionRegistry = [fixture.composition]
    fixture.project.layerRegistry = [fixture.top, adjustment, fixture.bottom]
    fixture.project = try fixture.project.validated()
    let resolver = try CountingFrameResolver()
    let result = try await CompositionGraphCompiler().compile(
        request(for: fixture),
        resolver: resolver,
        cancellationToken: RenderCancellationToken()
    )
    let ordered = try result.graph.evaluationPlan().orderedNodes
    let adjustmentIndex = try #require(ordered.firstIndex { if case .adjustment = $0.kind { return true }; return false })
    let lastCompositeIndex = try #require(ordered.lastIndex { if case .composite = $0.kind { return true }; return false })
    #expect(adjustmentIndex < lastCompositeIndex)
}
