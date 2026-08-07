from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def write(p,t): q=ROOT/p; q.parent.mkdir(parents=True,exist_ok=True); q.write_text(t)
write('Tests/VertexProjectTests/AIEffectBakeCommandTests.swift', r'''import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func bakeProject() throws -> (ProjectDocument, ProjectLayer, MediaReference) {
    var project = try ProjectDocument.makeNew(name: "Bake")
    let compositionID = try #require(project.activeCompositionID)
    var composition = try #require(project.composition(id: compositionID))
    let sourceMedia = MediaReference.fixture(id: "97000000-0000-0000-0000-000000000001", name: "source.mov")
    let sourceLayer = ProjectLayer(
        id: VertexID(rawValue: "97000000-0000-0000-0000-000000000010"),
        compositionID: compositionID,
        name: "Source",
        source: .media(mediaID: sourceMedia.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1))
    )
    composition.layerIDs = [sourceLayer.id]
    project.mediaRegistry = [sourceMedia]
    project.layerRegistry = [sourceLayer]
    project.compositionRegistry = [composition]
    project.selectedLayerID = sourceLayer.id
    return (try project.validated(), sourceLayer, sourceMedia)
}

private func bakeRegistration(source: ProjectLayer, sourceMedia: MediaReference) throws -> ProjectAIEffectBakeRegistration {
    let media = MediaReference(
        id: VertexID(rawValue: "97000000-0000-0000-0000-000000000002"),
        displayName: "Source • Depth.mov", originalFilename: "depth.mov", fileSize: 100,
        modificationDate: Date(timeIntervalSince1970: 1_700_500_000), contentFingerprint: "fingerprint",
        locator: MediaLocator(relativeHint: "depth.mov", embeddedPath: "Media/depth.mov"), kind: .video, availabilityStatus: .embedded
    )
    let recipe = ProjectAIRecipeReference(
        task: "depthMap", modelID: "depth-anything-v2-small-f16",
        modelDigest: String(repeating: "a", count: 64), recipeDigest: String(repeating: "b", count: 64), qualityTier: "balanced"
    )
    let asset = ProjectAIAsset(
        id: VertexID(rawValue: "97000000-0000-0000-0000-000000000003"), kind: .depth,
        sourceMediaID: sourceMedia.id, outputMediaID: media.id, recipe: recipe
    )
    let layer = ProjectLayer(
        id: VertexID(rawValue: "97000000-0000-0000-0000-000000000004"),
        compositionID: source.compositionID, name: "Source • Depth",
        source: .media(mediaID: media.id, sourceStartTime: .zero), timing: source.timing, transform: source.transform
    )
    return ProjectAIEffectBakeRegistration(media: media, aiAsset: asset, layer: layer, insertionIndex: 0)
}

@Test("Bake command registers media AI asset layer and selection atomically")
func bakeCommandRegistersAllDocumentState() throws {
    let (before, source, sourceMedia) = try bakeProject()
    let registration = try bakeRegistration(source: source, sourceMedia: sourceMedia)
    let engine = ProjectCommandEngine()
    let transition = try engine.prepare(
        ProjectCommandRequest(projectID: before.projectID, baseRevision: before.revision, payload: .registerBakedAIEffect(registration)), for: before
    )
    let after = try engine.apply(transition, to: before)
    #expect(after.mediaRegistry.contains(registration.media))
    #expect(after.aiAssetRegistry.contains(registration.aiAsset))
    #expect(after.layer(id: registration.layer.id) == registration.layer)
    #expect(after.composition(id: source.compositionID)?.layerIDs == [registration.layer.id, source.id])
    #expect(after.selectedLayerID == registration.layer.id)
}

@Test("Bake command inverse removes all registrations and restores selection/order")
func bakeCommandInverseIsExact() throws {
    var session = try ProjectEditingSession(document: bakeProject().0)
    let source = try #require(session.document.layerRegistry.first)
    let sourceMedia = try #require(session.document.mediaRegistry.first)
    let registration = try bakeRegistration(source: source, sourceMedia: sourceMedia)
    _ = try session.apply(ProjectCommandRequest(projectID: session.document.projectID, baseRevision: session.document.revision, payload: .registerBakedAIEffect(registration)))
    _ = try session.undo(commandID: VertexID(), timestamp: Date())
    #expect(session.document.mediaRegistry == [sourceMedia])
    #expect(session.document.aiAssetRegistry.isEmpty)
    #expect(session.document.layerRegistry == [source])
    #expect(session.document.composition(id: source.compositionID)?.layerIDs == [source.id])
    #expect(session.document.selectedLayerID == source.id)
}
''')

write('Tests/VertexAppTests/AIEffectBakeCoordinatorTests.swift', r'''import Foundation
import Testing
import VertexAI
import VertexCore
import VertexProject
@testable import Vertex

private actor FakeBakeProcessor: AIEffectBakeProcessing {
    enum Mode { case success, fail, cancel }
    let mode: Mode
    let result: AIEffectBakeProcessedOutput
    init(mode: Mode, result: AIEffectBakeProcessedOutput) { self.mode = mode; self.result = result }
    func process(sourceURL: URL, effect: ProjectEffect, outputRoot: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> AIEffectBakeProcessedOutput {
        onProgress(0.5)
        switch mode {
        case .success: return result
        case .fail: throw AIError.inferenceFailed("fixture failure")
        case .cancel: throw CancellationError()
        }
    }
}

private func coordinatorFixture() throws -> (ProjectDocument, ProjectLayer, ProjectEffect, URL, AIEffectBakeProcessedOutput) {
    var project = try ProjectDocument.makeNew(name: "Bake Coordinator")
    let compID = try #require(project.activeCompositionID)
    var comp = try #require(project.composition(id: compID))
    let source = MediaReference(
        id: VertexID(), displayName: "source.mov", originalFilename: "source.mov", fileSize: 3,
        modificationDate: Date(), contentFingerprint: AIDigest.sha256(Data([1,2,3])),
        locator: MediaLocator(embeddedPath: "Media/source.mov"), kind: .video, availabilityStatus: .embedded
    )
    let effect = ProjectEffect.makeDefault(.depthMap)
    let layer = ProjectLayer(compositionID: compID, name: "Source", source: .media(mediaID: source.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1)), effects: [effect])
    comp.layerIDs = [layer.id]; project.mediaRegistry=[source]; project.layerRegistry=[layer]; project.compositionRegistry=[comp]; project.selectedLayerID=layer.id
    project = try project.validated()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("Media", isDirectory: true), withIntermediateDirectories: true)
    try Data([1,2,3]).write(to: root.appendingPathComponent("Media/source.mov"))
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
    try Data([4,5,6,7]).write(to: outputURL)
    let processed = AIEffectBakeProcessedOutput(
        finalVideoURL: outputURL, modelID: "depth-anything-v2-small-f16", modelDigest: String(repeating:"a",count:64),
        recipeDigest: String(repeating:"b",count:64), qualityTier: "balanced", auxiliaryRelativePath: nil
    )
    return (project, layer, effect, root, processed)
}

@Test("Coordinator commits exactly once only after successful validated output")
@MainActor func coordinatorCommitsOnlyAfterSuccess() async throws {
    let fixture = try coordinatorFixture()
    var commits: [ProjectAIEffectBakeRegistration] = []
    let coordinator = AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: .success, result: fixture.4)) { commits.append($0) }
    try await coordinator.bake(project: fixture.0, packageURL: fixture.3, layerID: fixture.1.id, effectID: fixture.2.id)
    #expect(commits.count == 1)
    #expect(commits[0].layer.name == "Source • Depth")
    #expect(commits[0].media.availabilityStatus == .embedded)
}

@Test("Failure and cancellation never send a project command")
@MainActor func coordinatorFailureIsDocumentAtomic() async throws {
    for mode in [FakeBakeProcessor.Mode.fail, .cancel] {
        let fixture = try coordinatorFixture()
        var commitCount = 0
        let coordinator = AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: mode, result: fixture.4)) { _ in commitCount += 1 }
        do { try await coordinator.bake(project: fixture.0, packageURL: fixture.3, layerID: fixture.1.id, effectID: fixture.2.id) } catch {}
        #expect(commitCount == 0)
    }
}
''')
print('Task 9 RED tests applied')
