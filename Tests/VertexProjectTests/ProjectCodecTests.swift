import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("Equal project states encode to identical bytes")
func equalProjectsEncodeIdentically() throws {
    let project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "50000000-0000-0000-0000-000000000001"),
        name: "Deterministic",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let codec = DeterministicProjectCodec()
    #expect(try codec.encode(project) == codec.encode(project))
    #expect(try codec.checksum(project).count == 64)
}

@Test("Registry insertion order does not affect project bytes")
func registryOrderIsStable() throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
    let a = MediaReference.fixture(id: "50000000-0000-0000-0000-000000000010", name: "A.mov")
    let b = MediaReference.fixture(id: "50000000-0000-0000-0000-000000000011", name: "B.mov")
    let first = try ProjectDocument.makeFixture(timestamp: timestamp, media: [a, b])
    let second = try ProjectDocument.makeFixture(timestamp: timestamp, media: [b, a])
    let codec = DeterministicProjectCodec()
    #expect(try codec.encode(first) == codec.encode(second))
}

@Test("Non-finite render values are rejected")
func invalidFloatingPointIsRejected() throws {
    var project = try ProjectDocument.makeNew(name: "Invalid")
    project.renderSettings.exposure = .infinity
    #expect(throws: ProjectError.self) { try project.validated() }
}

@Test("A future schema is rejected before writable decoding")
func futureSchemaIsRejected() throws {
    let data = Data(#"{"schemaVersion":99,"minimumReaderVersion":99,"projectID":"50000000-0000-0000-0000-000000000001"}"#.utf8)
    #expect(throws: ProjectError.self) {
        try DeterministicProjectCodec().decode(data, supportedSchema: 1)
    }
}
