import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func bakeProject() throws -> (ProjectDocument, ProjectLayer, MediaReference) {
    var project = try ProjectDocument.makeNew(name: "Bake")
    var composition = ProjectComposition(
        id: VertexID(rawValue: "97000000-0000-0000-0000-000000000100"),
        name: "Main Composition",
        width: 1920,
        height: 1080,
        duration: RationalTime(value: 5, timescale: 1),
        frameRate: project.settings.frameRate,
        color: project.settings.color
    )
    let compositionID = composition.id
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
    project.activeCompositionID = compositionID
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
