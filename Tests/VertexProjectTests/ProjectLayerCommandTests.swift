import Foundation
import Testing
import VertexCore
@testable import VertexProject

private struct LayerCommandFixture {
    var document: ProjectDocument
    var composition: ProjectComposition
    var top: ProjectLayer
    var bottom: ProjectLayer
}

private func makeLayerCommandFixture() throws -> LayerCommandFixture {
    var document = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000001"),
        name: "Commands",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let media = MediaReference.fixture(id: "62000000-0000-0000-0000-000000000010")
    document.mediaRegistry = [media]
    var composition = document.compositionRegistry[0]
    let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: composition.duration)
    let top = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000021"),
        compositionID: composition.id,
        name: "Top",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: timing
    )
    let bottom = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000022"),
        compositionID: composition.id,
        name: "Bottom",
        source: .media(mediaID: media.id, sourceStartTime: .zero),
        timing: timing
    )
    composition.layerIDs = [top.id, bottom.id]
    document.compositionRegistry = [composition]
    document.layerRegistry = [top, bottom]
    document.selectedLayerID = top.id
    document.selectedMediaID = media.id
    return LayerCommandFixture(document: try document.validated(), composition: composition, top: top, bottom: bottom)
}

@Test("Layer reorder Undo restores exact authoritative Z-order")
func layerReorderUndoRestoresExactOrder() throws {
    let fixture = try makeLayerCommandFixture()
    let controller = try ProjectHistoryController(project: fixture.document)
    try controller.perform(.reorderLayer(
        compositionID: fixture.composition.id,
        layerID: fixture.bottom.id,
        beforeIndex: 1,
        afterIndex: 0
    ))
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs == [fixture.bottom.id, fixture.top.id])
    _ = try controller.undo()
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Layer insertion and removal restore the same identity and index")
func layerInsertRemoveRoundTrip() throws {
    let fixture = try makeLayerCommandFixture()
    let third = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000023"),
        compositionID: fixture.composition.id,
        name: "Third",
        source: .null,
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: fixture.composition.duration)
    )
    let controller = try ProjectHistoryController(project: fixture.document)
    try controller.perform(.insertLayer(third, compositionID: fixture.composition.id, index: 1))
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
    _ = try controller.undo()
    #expect(controller.project.layer(id: third.id) == nil)
    _ = try controller.redo()
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs[1] == third.id)
}

@Test("Locked layers reject edits except explicit unlock")
func lockedLayerPreconditions() throws {
    var fixture = try makeLayerCommandFixture()
    fixture.top.locked = true
    fixture.document.layerRegistry = [fixture.top, fixture.bottom]
    fixture.document = try fixture.document.validated()
    let record = ProjectCommandRecord(
        project: fixture.document,
        operation: .setLayerTransform(
            layerID: fixture.top.id,
            before: fixture.top.transform,
            after: LayerTransform(
                positionX: 0.7,
                positionY: 0.5,
                anchorX: 0.5,
                anchorY: 0.5,
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                opacity: 1
            )
        )
    )
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().apply(record, to: fixture.document)
    }

    let unlock = ProjectCommandRecord(
        project: fixture.document,
        operation: .setLayerLocked(layerID: fixture.top.id, before: true, after: false)
    )
    #expect(try ProjectCommandEngine().apply(unlock, to: fixture.document).layer(id: fixture.top.id)?.locked == false)
}

@Test("A composition referenced by a nested layer cannot be removed")
func referencedCompositionCannotBeRemoved() throws {
    var fixture = try makeLayerCommandFixture()
    let child = ProjectComposition(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000040"),
        name: "Child",
        width: 640,
        height: 360,
        duration: RationalTime(value: 10, timescale: 1),
        frameRate: RationalTime(value: 30, timescale: 1),
        color: .rec709SDR(alphaMode: .straight),
        backgroundColor: .transparent,
        layerIDs: []
    )
    let nested = ProjectLayer(
        id: VertexID(rawValue: "62000000-0000-0000-0000-000000000041"),
        compositionID: fixture.composition.id,
        name: "Nested Child",
        source: .composition(compositionID: child.id, sourceStartTime: .zero),
        timing: LayerTiming(startTime: .zero, inPoint: .zero, outPoint: fixture.composition.duration)
    )
    fixture.composition.layerIDs.insert(nested.id, at: 0)
    fixture.document.compositionRegistry = [fixture.composition, child]
    fixture.document.layerRegistry.append(nested)
    fixture.document = try fixture.document.validated()

    let record = ProjectCommandRecord(
        project: fixture.document,
        operation: .removeComposition(child, ownedLayers: [], registryIndex: 1)
    )
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().apply(record, to: fixture.document)
    }
}

@Test("Chained transform commands coalesce into one Undo entry")
func layerTransformCommandsCoalesce() throws {
    let fixture = try makeLayerCommandFixture()
    let controller = try ProjectHistoryController(project: fixture.document, coalescingInterval: 1)
    var first = fixture.top.transform
    first.positionX = 0.6
    var second = first
    second.positionX = 0.8
    try controller.perform(
        .setLayerTransform(layerID: fixture.top.id, before: fixture.top.transform, after: first),
        mergeKey: "layer.\(fixture.top.id.rawValue).transform.position",
        timestamp: Date(timeIntervalSince1970: 10)
    )
    try controller.perform(
        .setLayerTransform(layerID: fixture.top.id, before: first, after: second),
        mergeKey: "layer.\(fixture.top.id.rawValue).transform.position",
        timestamp: Date(timeIntervalSince1970: 10.2)
    )
    #expect(controller.undoCount == 1)
    _ = try controller.undo()
    #expect(controller.project.layer(id: fixture.top.id)?.transform == fixture.top.transform)
}
