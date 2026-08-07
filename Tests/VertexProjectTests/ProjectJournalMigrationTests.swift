import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("Future schemas are inspected but never decoded as writable projects")
func futureSchemaIsNonDestructive() throws {
    let data = Data(#"{"schemaVersion":99,"minimumReaderVersion":99,"projectID":"50000000-0000-0000-0000-000000000001","metadata":{"name":"Future","lastSavedByAppVersion":"99.0.0"}}"#.utf8)
    let info = try ProjectMigrationRegistry.current.inspect(data)
    #expect(info.schemaVersion == 99)
    #expect(info.projectName == "Future")
    #expect(throws: ProjectError.self) { try DeterministicProjectCodec().decode(data) }
}

@Test("Migration registry requires every sequential version link")
func missingMigrationLinkFails() throws {
    let registry = ProjectMigrationRegistry(migrators: [])
    let source = Data(#"{"schemaVersion":0,"minimumReaderVersion":0}"#.utf8)
    #expect(throws: ProjectError.self) {
        try registry.migrate(source, from: 0, to: 1)
    }
}
