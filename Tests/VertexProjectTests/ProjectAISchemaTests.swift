import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func aiDocument() throws -> ProjectDocument {
    let source = MediaReference.fixture(
        id: "73100000-0000-0000-0000-000000000001",
        name: "source.mov"
    )
    let output = MediaReference.fixture(
        id: "73100000-0000-0000-0000-000000000002",
        name: "depth.mov",
        fingerprint: "depth-fingerprint"
    )
    return try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_200_000),
        media: [source, output]
    )
}

private func aiAsset() -> ProjectAIAsset {
    ProjectAIAsset(
        id: VertexID(rawValue: "73100000-0000-0000-0000-000000000003"),
        kind: .depth,
        sourceMediaID: VertexID(rawValue: "73100000-0000-0000-0000-000000000001"),
        outputMediaID: VertexID(rawValue: "73100000-0000-0000-0000-000000000002"),
        recipe: ProjectAIRecipeReference(
            task: "depth",
            modelID: "depth-anything-v2-small-f16",
            modelDigest: String(repeating: "a", count: 64),
            recipeDigest: String(repeating: "b", count: 64),
            qualityTier: "balanced"
        )
    )
}

@Test("New projects use schema 6 and the current app version")
func newProjectUsesCurrentSchema() throws {
    let document = try aiDocument()
    #expect(ProjectDocument.currentSchemaVersion == 6)
    #expect(document.schemaVersion == ProjectDocument.currentSchemaVersion)
    #expect(document.metadata.createdByAppVersion == ProjectDocument.currentAppVersion)
    #expect(document.metadata.lastSavedByAppVersion == ProjectDocument.currentAppVersion)
    #expect(document.compositionRegistry.allSatisfy { $0.nodeGraph == nil })
    #expect(document.aiAssetRegistry.isEmpty)
}

@Test("AI assets register through reversible command mutations")
func aiAssetCommandRoundTrip() throws {
    let engine = ProjectCommandEngine()
    let document = try aiDocument()
    let asset = aiAsset()
    let request = ProjectCommandRequest(
        commandID: VertexID(rawValue: "73100000-0000-0000-0000-000000000004"),
        projectID: document.projectID,
        baseRevision: document.revision,
        timestamp: Date(timeIntervalSince1970: 1_700_200_001),
        payload: .registerAIAsset(asset)
    )
    let transition = try engine.prepare(request, for: document)
    let registered = try engine.apply(transition, to: document)

    #expect(registered.aiAssetRegistry == [asset])
    #expect(transition.inverse == .removeAIAsset(asset))

    let inverse = ProjectTransition(
        commandID: VertexID(rawValue: "73100000-0000-0000-0000-000000000005"),
        projectID: registered.projectID,
        baseRevision: registered.revision,
        timestamp: Date(timeIntervalSince1970: 1_700_200_002),
        mergeKey: nil,
        forward: transition.inverse,
        inverse: transition.forward
    )
    let removed = try engine.apply(inverse, to: registered)
    #expect(removed.aiAssetRegistry.isEmpty)
}

@Test("Media referenced by AI assets cannot be removed")
func aiReferencedMediaCannotBeRemoved() throws {
    let engine = ProjectCommandEngine()
    let document = try aiDocument()
    let asset = aiAsset()
    let register = try engine.prepare(
        ProjectCommandRequest(
            projectID: document.projectID,
            baseRevision: document.revision,
            payload: .registerAIAsset(asset)
        ),
        for: document
    )
    let registered = try engine.apply(register, to: document)

    #expect(throws: ProjectError.self) {
        _ = try engine.prepare(
            ProjectCommandRequest(
                projectID: registered.projectID,
                baseRevision: registered.revision,
                payload: .removeMedia(id: asset.outputMediaID)
            ),
            for: registered
        )
    }
}

@Test("Canonical JSON contains references but no runtime cache state")
func aiAssetCanonicalJSONIsReferenceOnly() throws {
    let engine = ProjectCommandEngine()
    let document = try aiDocument()
    let asset = aiAsset()
    let transition = try engine.prepare(
        ProjectCommandRequest(
            projectID: document.projectID,
            baseRevision: document.revision,
            payload: .registerAIAsset(asset)
        ),
        for: document
    )
    let registered = try engine.apply(transition, to: document)
    let json = String(decoding: try DeterministicProjectCodec().encode(registered), as: UTF8.self)

    #expect(json.contains("aiAssetRegistry"))
    #expect(json.contains("recipeDigest"))
    #expect(!json.contains("completedChunks"))
    #expect(!json.contains("neuralEngineCache"))
    #expect(!json.contains("runtimeModelState"))
}
