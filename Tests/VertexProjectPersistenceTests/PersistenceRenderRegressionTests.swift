import Foundation
import Testing
import VertexComposition
import VertexCore
import VertexMedia
import VertexProject
import VertexRender
@testable import VertexProjectPersistence

private actor PersistenceRenderFixtureResolver: CompositionFrameResolver {
    private let image: PortableImage

    init() throws {
        image = try PortableImage(
            data: Data([1, 2, 3, 4]),
            format: .png,
            pixelSize: VertexSize(width: 32, height: 18)
        )
    }

    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution {
        .frame(image)
    }
}

@Test("Saved and reopened schema 2 project compiles to the same render DAG and cache key")
func savedSchema2RenderGraphIsStableAcrossReopen() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("vertex-persistence-render-\(UUID().uuidString)", isDirectory: true)
    let packageURL = root.appendingPathComponent("Render Regression").appendingPathExtension("vertexproject")
    defer { try? FileManager.default.removeItem(at: root) }

    let projectID = VertexID(rawValue: "6a000000-0000-0000-0000-000000000001")
    let mediaID = VertexID(rawValue: "6a000000-0000-0000-0000-000000000002")
    let layerID = VertexID(rawValue: "6a000000-0000-0000-0000-000000000003")
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    var document = try ProjectDocument.makeNew(id: projectID, name: "Render Regression", timestamp: timestamp)
    let compositionID = try #require(document.activeCompositionID)
    var composition = try #require(document.composition(id: compositionID))
    composition.width = 32
    composition.height = 18
    composition.duration = RationalTime(value: 2, timescale: 1)
    let media = MediaReference.fixture(id: mediaID.rawValue, name: "fixture.mov")
    let layer = ProjectLayer(
        id: layerID,
        compositionID: compositionID,
        name: "Fixture Layer",
        source: .media(mediaID: mediaID, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration),
        transform: LayerTransform(
            positionX: 0.55,
            positionY: 0.45,
            anchorX: 0.5,
            anchorY: 0.5,
            scaleX: 1.1,
            scaleY: 0.9,
            rotationDegrees: 8,
            opacity: 0.85
        ),
        blendMode: .screen,
        operations: [.exposure(stops: 0.5), .saturation(value: 1.2)]
    )
    composition.layerIDs = [layerID]
    document.mediaRegistry = [media]
    document.compositionRegistry = [composition]
    document.layerRegistry = [layer]
    document.selectedLayerID = layerID
    document.selectedMediaID = mediaID
    document = try document.validated()

    let output = try RenderOutputSpecification(width: 32, height: 18)
    let time = RationalTime(value: 1, timescale: 2)
    let resolverBefore = try PersistenceRenderFixtureResolver()
    let before = try await CompositionGraphCompiler().compile(
        CompositionRenderRequest(
            project: document,
            compositionID: compositionID,
            time: time,
            output: output
        ),
        resolver: resolverBefore,
        cancellationToken: RenderCancellationToken()
    )

    _ = try VertexProjectPackageStore().create(at: packageURL, document: document)
    guard case .opened(let reopenedSnapshot) = try VertexProjectPackageStore().open(at: packageURL) else {
        Issue.record("Saved schema 2 package should reopen directly.")
        return
    }
    let resolverAfter = try PersistenceRenderFixtureResolver()
    let after = try await CompositionGraphCompiler().compile(
        CompositionRenderRequest(
            project: reopenedSnapshot.document,
            compositionID: compositionID,
            time: time,
            output: output
        ),
        resolver: resolverAfter,
        cancellationToken: RenderCancellationToken()
    )

    let beforeNodeCount = try before.graph.evaluationPlan().orderedNodes.count
    let afterNodeCount = try after.graph.evaluationPlan().orderedNodes.count
    #expect(reopenedSnapshot.document == document)
    #expect(after.graph == before.graph)
    #expect(after.cacheKey == before.cacheKey)
    #expect(afterNodeCount == beforeNodeCount)
}
