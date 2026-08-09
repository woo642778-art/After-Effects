import Foundation
import Testing
import VertexAI
import VertexCore
import VertexProject
@testable import Vertex

private struct FakeBakeOutputValidator: AIEffectBakeOutputValidating {
    enum Mode { case accept, reject }
    let mode: Mode
    func validate(sourceURL: URL, outputURL: URL) async throws {
        if mode == .reject {
            throw AIError.invalidJobState("malformed baked movie fixture")
        }
    }
}

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
    let compID = VertexID()
    var comp = ProjectComposition(
        id: compID,
        name: "Main",
        width: 1920,
        height: 1080,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: project.settings.color,
        backgroundColor: .transparent,
        layerIDs: []
    )
    project.compositionRegistry = [comp]
    project.activeCompositionID = compID
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
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathExtension("vertexproject")
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
    let coordinator = AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: .success, result: fixture.4), validator: FakeBakeOutputValidator(mode: .accept)) { commits.append($0) }
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
        let coordinator = AIEffectBakeCoordinator(processor: FakeBakeProcessor(mode: mode, result: fixture.4), validator: FakeBakeOutputValidator(mode: .accept)) { _ in commitCount += 1 }
        do { try await coordinator.bake(project: fixture.0, packageURL: fixture.3, layerID: fixture.1.id, effectID: fixture.2.id) } catch {}
        #expect(commitCount == 0)
    }
}

@Test("Malformed finalized media is rejected before the project command")
@MainActor func coordinatorRejectsMalformedFinalMedia() async throws {
    let fixture = try coordinatorFixture()
    var commitCount = 0
    let coordinator = AIEffectBakeCoordinator(
        processor: FakeBakeProcessor(mode: .success, result: fixture.4),
        validator: FakeBakeOutputValidator(mode: .reject)
    ) { _ in
        commitCount += 1
    }
    do {
        try await coordinator.bake(
            project: fixture.0,
            packageURL: fixture.3,
            layerID: fixture.1.id,
            effectID: fixture.2.id
        )
        Issue.record("Expected malformed output validation failure")
    } catch {}
    #expect(commitCount == 0)
}
