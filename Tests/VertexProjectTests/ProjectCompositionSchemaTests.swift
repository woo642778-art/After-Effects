import Foundation
import Testing
import VertexCore
@testable import VertexProject

private let projectID = VertexID(rawValue: "60000000-0000-0000-0000-000000000001")
private let compositionID = VertexID(rawValue: "60000000-0000-0000-0000-000000000002")
private let topLayerID = VertexID(rawValue: "60000000-0000-0000-0000-000000000012")
private let bottomLayerID = VertexID(rawValue: "60000000-0000-0000-0000-000000000011")
private let mediaID = VertexID(rawValue: "60000000-0000-0000-0000-000000000020")

private func makeComposition(id: VertexID = compositionID, layerIDs: [VertexID]) -> ProjectComposition {
    ProjectComposition(id: id, name: "Main Composition", width: 1920, height: 1080, duration: RationalTime(value: 10, timescale: 1), frameRate: RationalTime(value: 30, timescale: 1), color: .rec709SDR(alphaMode: .straight), backgroundColor: .transparent, layerIDs: layerIDs)
}

private func makeMediaLayer(id: VertexID, compositionID: VertexID, mediaID: VertexID, name: String) -> ProjectLayer {
    ProjectLayer(id: id, compositionID: compositionID, name: name, source: .media(mediaID: mediaID, sourceStartTime: .zero), enabled: true, locked: false, solo: false, timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1)), transform: .identity, blendMode: .normal, operations: [])
}

private func makeDocument(compositions: [ProjectComposition], layers: [ProjectLayer], activeCompositionID: VertexID? = compositionID, selectedLayerID: VertexID? = topLayerID, selectedMediaID: VertexID? = mediaID) -> ProjectDocument {
    ProjectDocument(projectID: projectID, revision: 0, metadata: ProjectMetadata(name: "Schema 2 Fixture", createdAt: Date(timeIntervalSince1970: 1_700_000_000), modifiedAt: Date(timeIntervalSince1970: 1_700_000_000), createdByAppVersion: "6.0.0", lastSavedByAppVersion: "6.0.0"), settings: ProjectSettings(), mediaRegistry: [MediaReference.fixture(id: mediaID.rawValue)], compositionRegistry: compositions, layerRegistry: layers, activeCompositionID: activeCompositionID, selectedLayerID: selectedLayerID, selectedMediaID: selectedMediaID)
}

@Test("New corrected schema 2 projects contain one active empty composition")
func newProjectContainsMainComposition() throws {
    let project = try ProjectDocument.makeNew(id: projectID, name: "New", timestamp: Date(timeIntervalSince1970: 1_700_000_000))
    #expect(project.schemaVersion == 2)
    #expect(project.compositionRegistry.count == 1)
    #expect(project.layerRegistry.isEmpty)
    #expect(project.activeCompositionID == project.compositionRegistry[0].id)
    #expect(project.compositionRegistry[0].name == "Main Composition")
}

@Test("Canonical schema 2 preserves Z-order and excludes persistence compatibility fields")
func canonicalSchemaPreservesZOrderAndStaysClean() throws {
    let composition = makeComposition(layerIDs: [topLayerID, bottomLayerID])
    let top = makeMediaLayer(id: topLayerID, compositionID: composition.id, mediaID: mediaID, name: "Top")
    let bottom = makeMediaLayer(id: bottomLayerID, compositionID: composition.id, mediaID: mediaID, name: "Bottom")
    let document = makeDocument(compositions: [composition], layers: [top, bottom])
    let codec = DeterministicProjectCodec()
    let encoded = try codec.encode(document)
    let decoded = try codec.decode(encoded)
    let json = String(decoding: encoded, as: UTF8.self)
    #expect(decoded.layerRegistry.map(\.id) == [bottomLayerID, topLayerID])
    #expect(decoded.composition(id: composition.id)?.layerIDs == [topLayerID, bottomLayerID])
    #expect(!json.contains("bookmarkData"))
    #expect(!json.contains("appliedCommandIDs"))
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("undoHistory"))
    #expect(!json.contains("redoHistory"))
    #expect(!json.contains("inverseOperation"))
}

@Test("Invalid persisted navigation normalizes without entering product state")
func invalidNavigationNormalizes() throws {
    let composition = makeComposition(layerIDs: [])
    let document = makeDocument(compositions: [composition], layers: [], activeCompositionID: VertexID(rawValue: "60000000-0000-0000-0000-000000000099"), selectedLayerID: VertexID(rawValue: "60000000-0000-0000-0000-000000000098"), selectedMediaID: VertexID(rawValue: "60000000-0000-0000-0000-000000000097"))
    let codec = DeterministicProjectCodec()
    let decoded = try codec.decode(codec.encode(document))
    #expect(decoded.activeCompositionID == composition.id)
    #expect(decoded.selectedLayerID == nil)
    #expect(decoded.selectedMediaID == nil)
}

@Test("Model-only layers reject pixel operations and non-normal blending")
func modelOnlyRestrictionsAreValidated() throws {
    let cameraID = VertexID(rawValue: "60000000-0000-0000-0000-000000000030")
    let composition = makeComposition(layerIDs: [cameraID])
    let camera = ProjectLayer(id: cameraID, compositionID: composition.id, name: "Camera", source: .camera(.default), enabled: true, locked: false, solo: false, timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1)), transform: .identity, blendMode: .screen, operations: [.invert(enabled: true)])
    let document = makeDocument(compositions: [composition], layers: [camera], selectedLayerID: cameraID)
    #expect(throws: ProjectError.self) { try document.validated() }
}

@Test("Direct and indirect nested composition cycles are rejected")
func nestedCyclesAreRejected() throws {
    let a = VertexID(rawValue: "60000000-0000-0000-0000-000000000101")
    let b = VertexID(rawValue: "60000000-0000-0000-0000-000000000102")
    let c = VertexID(rawValue: "60000000-0000-0000-0000-000000000103")
    let la = VertexID(rawValue: "60000000-0000-0000-0000-000000000111")
    let lb = VertexID(rawValue: "60000000-0000-0000-0000-000000000112")
    let lc = VertexID(rawValue: "60000000-0000-0000-0000-000000000113")
    func nestedLayer(id: VertexID, owner: VertexID, target: VertexID) -> ProjectLayer {
        ProjectLayer(id: id, compositionID: owner, name: "Nested", source: .composition(compositionID: target, sourceStartTime: .zero), enabled: true, locked: false, solo: false, timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 10, timescale: 1)), transform: .identity, blendMode: .normal, operations: [])
    }
    let direct = makeDocument(compositions: [makeComposition(id: a, layerIDs: [la])], layers: [nestedLayer(id: la, owner: a, target: a)], activeCompositionID: a, selectedLayerID: la, selectedMediaID: nil)
    #expect(throws: ProjectError.self) { try direct.validated() }
    let indirect = makeDocument(compositions: [makeComposition(id: a, layerIDs: [la]), makeComposition(id: b, layerIDs: [lb]), makeComposition(id: c, layerIDs: [lc])], layers: [nestedLayer(id: la, owner: a, target: b), nestedLayer(id: lb, owner: b, target: c), nestedLayer(id: lc, owner: c, target: a)], activeCompositionID: a, selectedLayerID: la, selectedMediaID: nil)
    #expect(throws: ProjectError.self) { try indirect.validated() }
}
