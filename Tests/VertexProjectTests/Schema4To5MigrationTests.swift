import Foundation
import Testing
@testable import VertexProject

@Suite("Schema 4 to 5 migration")
struct Schema4To5MigrationTests {
    @Test func migrationPreservesDocumentAndInitializesTimelineDefaults() throws {
        let current = try ProjectDocument.makeNew(name: "Migration")
        let encoded = try DeterministicProjectCodec().encode(current)
        var root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        root["schemaVersion"] = 4
        root["minimumReaderVersion"] = 4
        if var metadata = root["metadata"] as? [String: Any] {
            metadata["lastSavedByAppVersion"] = "8.0.0"
            root["metadata"] = metadata
        }
        if var compositions = root["compositionRegistry"] as? [[String: Any]] {
            for index in compositions.indices {
                compositions[index].removeValue(forKey: "workArea")
                compositions[index].removeValue(forKey: "markers")
                compositions[index].removeValue(forKey: "nodeGraph")
            }
            root["compositionRegistry"] = compositions
        }
        let schema4Data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        let result = try ProjectMigrationRegistry.current.migrate(schema4Data, from: 4, to: 5)
        let migrated = try Schema5ProjectCodec.decode(result.data)
        #expect(migrated.schemaVersion == 5)
        #expect(migrated.metadata.lastSavedByAppVersion == "9.0.0")
        #expect(migrated.compositionRegistry.allSatisfy { $0.workArea == nil && $0.markers.isEmpty && $0.nodeGraph == nil })
        #expect(migrated.layerRegistry.allSatisfy { $0.timing.sourceOffset == .zero && $0.parentLayerID == nil })
    }
}
