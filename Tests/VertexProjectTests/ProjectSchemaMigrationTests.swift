import Foundation
import Testing
import VertexCore
@testable import VertexProject

private func schema1Data(selectedMedia: Bool, includePlaceholder: Bool) throws -> Data {
    let projectID = "61000000-0000-0000-0000-000000000001"
    let mediaID = "61000000-0000-0000-0000-000000000010"
    let compositionID = "61000000-0000-0000-0000-000000000020"
    let timestamp = "2023-11-14T22:13:20.000Z"

    var root: [String: Any] = [
        "schemaVersion": 1,
        "minimumReaderVersion": 1,
        "projectID": projectID,
        "revision": 7,
        "metadata": [
            "name": "Legacy Project",
            "createdAt": timestamp,
            "modifiedAt": timestamp,
            "createdByAppVersion": "5.0.0",
            "lastSavedByAppVersion": "5.0.0"
        ],
        "settings": [
            "frameRate": ["value": 30, "timescale": 1],
            "color": [
                "primaries": "rec709",
                "transferFunction": "rec709",
                "matrix": "bt709",
                "alphaMode": "straight"
            ]
        ],
        "mediaRegistry": [[
            "id": mediaID,
            "displayName": "legacy.mov",
            "originalFilename": "legacy.mov",
            "fileSize": 100,
            "modificationDate": timestamp,
            "contentFingerprint": "legacy-fingerprint",
            "locator": ["relativeHint": "legacy.mov"],
            "kind": "video",
            "availabilityStatus": "external"
        ]],
        "compositionRegistry": includePlaceholder ? [["id": compositionID, "name": "Legacy Comp"]] : [],
        "renderSettings": [
            "exposure": 1.25,
            "saturation": 1.5,
            "opacity": 0.75,
            "inverted": true,
            "scale": 1.2,
            "translationX": 0.1,
            "translationY": -0.2,
            "outputWidth": 1920,
            "outputHeight": 1080
        ]
    ]
    root["activeCompositionID"] = includePlaceholder ? compositionID : NSNull()
    root["selectedMediaID"] = selectedMedia ? mediaID : NSNull()
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
}

@Test("Selected schema 1 media becomes one deterministic media layer")
func selectedMediaMigratesDeterministically() throws {
    let input = try schema1Data(selectedMedia: true, includePlaceholder: true)
    let first = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let second = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    #expect(first.data == second.data)

    let project = try DeterministicProjectCodec().decode(first.data)
    #expect(project.schemaVersion == 2)
    #expect(project.revision == 7)
    #expect(project.compositionRegistry.count == 1)
    #expect(project.layerRegistry.count == 1)
    #expect(project.layerRegistry[0].transform.opacity == 0.75)
    #expect(project.layerRegistry[0].transform.scaleX == 1.2)
    #expect(project.layerRegistry[0].transform.positionX == 0.6)
    #expect(project.layerRegistry[0].operations.contains(.exposure(stops: 1.25)))
    #expect(project.layerRegistry[0].operations.contains(.saturation(value: 1.5)))
    #expect(project.layerRegistry[0].operations.contains(.invert(enabled: true)))
    #expect(project.selectedLayerID == project.layerRegistry[0].id)

    let json = try #require(String(data: first.data, encoding: .utf8))
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("appliedCommandIDs"))
    #expect(!json.contains("bookmarkData"))
    #expect(!json.contains("\"renderSettings\""))
}

@Test("Schema 1 without selected media converts Render Lab values into an adjustment layer")
func noSelectionConvertsLegacyValues() throws {
    let input = try schema1Data(selectedMedia: false, includePlaceholder: false)
    let result = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let project = try DeterministicProjectCodec().decode(result.data)

    #expect(project.compositionRegistry.count == 1)
    #expect(project.compositionRegistry[0].name == "Main Composition")
    #expect(project.compositionRegistry[0].width == 1920)
    #expect(project.compositionRegistry[0].height == 1080)
    #expect(project.layerRegistry.count == 1)
    #expect(project.layerRegistry[0].source == .adjustment(scope: .belowAll))
    #expect(project.layerRegistry[0].transform.opacity == 0.75)
    #expect(project.layerRegistry[0].operations.contains(.exposure(stops: 1.25)))
    #expect(project.selectedLayerID == project.layerRegistry[0].id)
}

@Test("Stable derived IDs are repeatable and domain separated")
func stableDerivedIDsAreDomainSeparated() throws {
    let first = try DeterministicVertexID.derive(domain: "vertex.phase6.layer", components: ["a", "b"])
    let second = try DeterministicVertexID.derive(domain: "vertex.phase6.layer", components: ["a", "b"])
    let other = try DeterministicVertexID.derive(domain: "vertex.phase6.composition", components: ["a", "b"])
    #expect(first == second)
    #expect(first != other)
}
