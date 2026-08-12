import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Suite("Schema 5 to 6 node graph migration")
struct Schema5To6NodeGraphMigrationTests {
    @Test func migrationPreservesSchema5ContentAndAddsEmptyNodeGraphs() throws {
        let current = try ProjectDocument.makeFixture(timestamp: Date(timeIntervalSince1970: 1_700_000_000), media: [])
        let data = try DeterministicProjectCodec().encode(current)
        let result = try Schema5To6Migrator().migrate(data)
        let header = try ProjectSchemaHeader.decode(from: result.data)
        #expect(header.schemaVersion == 6)
        #expect(result.report.sourceVersion == 5)
        #expect(result.report.destinationVersion == 6)

        let decoded = try DeterministicProjectCodec().decode(result.data, supportedSchema: 6)
        #expect(decoded.schemaVersion == 6)
        #expect(decoded.compositionRegistry.allSatisfy { $0.nodeGraph == nil })
    }

    @Test func schema6RoundTripsACompositionNodeGraphDeterministically() throws {
        var document = try ProjectDocument.makeFixture(timestamp: Date(timeIntervalSince1970: 1_700_000_000), media: [])
        let compositionID = try #require(document.activeCompositionID)
        let source = ProjectNode(name: "Solid", kind: .solidColor(ProjectRGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)), position: .init(x: 30, y: 50))
        let output = ProjectNode(name: "Output", kind: .output, position: .init(x: 340, y: 50))
        let graph = ProjectNodeGraph(
            compositionID: compositionID,
            nodes: [source, output],
            connections: [.init(from: .init(nodeID: source.id, portID: "image"), to: .init(nodeID: output.id, portID: "image"))]
        )
        let index = try #require(document.compositionRegistry.firstIndex(where: { $0.id == compositionID }))
        document.compositionRegistry[index].nodeGraph = graph
        _ = try document.validated()

        let codec = DeterministicProjectCodec()
        let first = try codec.encode(document)
        let decoded = try codec.decode(first)
        let second = try codec.encode(decoded)
        #expect(first == second)
        #expect(decoded.composition(id: compositionID)?.nodeGraph == graph)
        #expect(ProjectDocument.currentSchemaVersion == 6)
        #expect(ProjectDocument.currentAppVersion == "18.0.0")
    }
}
