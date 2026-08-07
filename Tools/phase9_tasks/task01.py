from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text()

def write(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)

def replace_once(path, old, new):
    text = read(path)
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f"marker not found in {path}: {old[:120]!r}")
    write(path, text.replace(old, new, 1))

# New exact-time timeline primitives.
write("Sources/VertexProject/ProjectTimeline.swift", r'''import Foundation
import VertexCore

public struct ProjectMarker: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var name: String
    public var comment: String

    public init(
        id: VertexID = VertexID(),
        time: RationalTime,
        name: String,
        comment: String = ""
    ) {
        self.id = id
        self.time = time
        self.name = name
        self.comment = comment
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard time >= .zero, time < compositionDuration else {
            throw ProjectError.invalidValue("Marker time must satisfy 0 <= time < composition duration.")
        }
        return self
    }
}

public struct ProjectWorkArea: Codable, Equatable, Sendable {
    public var start: RationalTime
    public var end: RationalTime

    public init(start: RationalTime, end: RationalTime) {
        self.start = start
        self.end = end
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard start >= .zero, start < end, end <= compositionDuration else {
            throw ProjectError.invalidValue("Work area must satisfy 0 <= start < end <= composition duration.")
        }
        return self
    }
}
''')

# LayerTiming: separate composition placement/source offset and schema-4 decode compatibility.
layer_path = "Sources/VertexProject/ProjectLayer.swift"
text = read(layer_path)
start = text.index("public struct LayerTiming:")
end = text.index("public struct LayerTransform:")
new_timing = r'''public struct LayerTiming: Codable, Equatable, Sendable {
    public var startTime: RationalTime
    public var inPoint: RationalTime
    public var outPoint: RationalTime
    public var sourceOffset: RationalTime

    private enum CodingKeys: String, CodingKey {
        case startTime
        case inPoint
        case outPoint
        case sourceOffset
    }

    public init(
        startTime: RationalTime,
        inPoint: RationalTime,
        outPoint: RationalTime,
        sourceOffset: RationalTime = .zero
    ) {
        self.startTime = startTime
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.sourceOffset = sourceOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(RationalTime.self, forKey: .startTime)
        inPoint = try container.decode(RationalTime.self, forKey: .inPoint)
        outPoint = try container.decode(RationalTime.self, forKey: .outPoint)
        sourceOffset = try container.decodeIfPresent(RationalTime.self, forKey: .sourceOffset) ?? .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(inPoint, forKey: .inPoint)
        try container.encode(outPoint, forKey: .outPoint)
        try container.encode(sourceOffset, forKey: .sourceOffset)
    }

    public func validated(for composition: ProjectComposition) throws -> Self {
        guard inPoint >= .zero, inPoint < outPoint, outPoint <= composition.duration else {
            throw ProjectError.invalidValue("Layer timing must satisfy 0 <= In < Out <= composition duration.")
        }
        guard sourceOffset >= .zero else {
            throw ProjectError.invalidValue("Layer source offset must be nonnegative.")
        }
        return self
    }
}

'''
text = text[:start] + new_timing + text[end:]

# Add parent field / coding / initializer / validation if not already present.
if "public var parentLayerID: VertexID?" not in text:
    text = text.replace(
        "    public var trackMatte: ProjectTrackMatte?\n",
        "    public var trackMatte: ProjectTrackMatte?\n    public var parentLayerID: VertexID?\n",
        1,
    )
    text = text.replace(
        "        case trackMatte\n",
        "        case trackMatte\n        case parentLayerID\n",
        1,
    )
    text = text.replace(
        "        trackMatte: ProjectTrackMatte? = nil\n    ) {",
        "        trackMatte: ProjectTrackMatte? = nil,\n        parentLayerID: VertexID? = nil\n    ) {",
        1,
    )
    text = text.replace(
        "        self.trackMatte = trackMatte\n",
        "        self.trackMatte = trackMatte\n        self.parentLayerID = parentLayerID\n",
        1,
    )
    text = text.replace(
        "        trackMatte = try container.decodeIfPresent(ProjectTrackMatte.self, forKey: .trackMatte)\n",
        "        trackMatte = try container.decodeIfPresent(ProjectTrackMatte.self, forKey: .trackMatte)\n        parentLayerID = try container.decodeIfPresent(VertexID.self, forKey: .parentLayerID)\n",
        1,
    )
    text = text.replace(
        "        try container.encodeIfPresent(trackMatte, forKey: .trackMatte)\n",
        "        try container.encodeIfPresent(trackMatte, forKey: .trackMatte)\n        try container.encodeIfPresent(parentLayerID, forKey: .parentLayerID)\n",
        1,
    )

parent_validation_anchor = "        if let trackMatte {\n"
if "Parent relationships must not contain a cycle." not in text:
    idx = text.index(parent_validation_anchor)
    parent_validation = r'''        if let parentLayerID {
            guard parentLayerID != id,
                  let parentLayer = document.layer(id: parentLayerID),
                  parentLayer.compositionID == compositionID else {
                throw ProjectError.invalidValue("Layer parent must reference another layer in the same composition.")
            }
            var visited: Set<VertexID> = [id]
            var candidate: ProjectLayer? = parentLayer
            while let current = candidate {
                guard visited.insert(current.id).inserted else {
                    throw ProjectError.invalidValue("Parent relationships must not contain a cycle.")
                }
                candidate = current.parentLayerID.flatMap { document.layer(id: $0) }
            }
        }

'''
    text = text[:idx] + parent_validation + text[idx:]
write(layer_path, text)

# Composition gains deterministic work area + marker state with schema-4 decode defaults.
write("Sources/VertexProject/ProjectComposition.swift", r'''import Foundation
import VertexCore

public struct ProjectComposition: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var width: Int
    public var height: Int
    public var duration: RationalTime
    public var frameRate: RationalTime
    public var color: ColorDescriptor
    public var backgroundColor: ProjectRGBAColor
    public var layerIDs: [VertexID]
    public var workArea: ProjectWorkArea?
    public var markers: [ProjectMarker]

    private enum CodingKeys: String, CodingKey {
        case id, name, width, height, duration, frameRate, color, backgroundColor, layerIDs, workArea, markers
    }

    public init(
        id: VertexID = VertexID(),
        name: String,
        width: Int,
        height: Int,
        duration: RationalTime,
        frameRate: RationalTime,
        color: ColorDescriptor,
        backgroundColor: ProjectRGBAColor = .transparent,
        layerIDs: [VertexID] = [],
        workArea: ProjectWorkArea? = nil,
        markers: [ProjectMarker] = []
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.duration = duration
        self.frameRate = frameRate
        self.color = color
        self.backgroundColor = backgroundColor
        self.layerIDs = layerIDs
        self.workArea = workArea
        self.markers = markers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(VertexID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        duration = try container.decode(RationalTime.self, forKey: .duration)
        frameRate = try container.decode(RationalTime.self, forKey: .frameRate)
        color = try container.decode(ColorDescriptor.self, forKey: .color)
        backgroundColor = try container.decode(ProjectRGBAColor.self, forKey: .backgroundColor)
        layerIDs = try container.decode([VertexID].self, forKey: .layerIDs)
        workArea = try container.decodeIfPresent(ProjectWorkArea.self, forKey: .workArea)
        markers = try container.decodeIfPresent([ProjectMarker].self, forKey: .markers) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(duration, forKey: .duration)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(color, forKey: .color)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(layerIDs, forKey: .layerIDs)
        try container.encodeIfPresent(workArea, forKey: .workArea)
        try container.encode(markers, forKey: .markers)
    }

    public func validated(layerByID: [VertexID: ProjectLayer]) throws -> Self {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectError.invalidValue("Composition name must not be empty.")
        }
        guard (1...8192).contains(width), (1...8192).contains(height) else {
            throw ProjectError.invalidValue("Composition dimensions must be between 1 and 8192 pixels.")
        }
        guard duration > .zero else {
            throw ProjectError.invalidValue("Composition duration must be positive.")
        }
        guard frameRate > .zero else {
            throw ProjectError.invalidValue("Composition frame rate must be positive.")
        }
        guard layerIDs.count <= 256 else {
            throw ProjectError.invalidValue("A composition may contain at most 256 layers.")
        }
        guard Set(layerIDs).count == layerIDs.count else {
            throw ProjectError.duplicateIdentity("composition layer order")
        }
        _ = try backgroundColor.validated()
        if let workArea { _ = try workArea.validated(compositionDuration: duration) }
        guard Set(markers.map(\.id)).count == markers.count else {
            throw ProjectError.duplicateIdentity("composition marker")
        }
        for marker in markers { _ = try marker.validated(compositionDuration: duration) }
        for layerID in layerIDs {
            guard let layer = layerByID[layerID] else {
                throw ProjectError.invalidValue("Composition layer order references a missing layer: \(layerID.rawValue).")
            }
            guard layer.compositionID == id else {
                throw ProjectError.invalidValue("Layer ownership does not match its composition order.")
            }
        }
        return self
    }
}
''')

# Advance current schema/app version.
replace_once(
    "Sources/VertexProject/ProjectSchema.swift",
    'public static let currentSchemaVersion = 4\n    public static let currentAppVersion = "8.0.0"',
    'public static let currentSchemaVersion = 5\n    public static let currentAppVersion = "9.0.0"',
)

# Schema-4 compatibility codec and migrator.
write("Sources/VertexProject/Schema4To5Migrator.swift", r'''import Foundation
import VertexCore

struct Schema4ProjectDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var minimumReaderVersion: Int
    var projectID: VertexID
    var revision: UInt64
    var metadata: ProjectMetadata
    var settings: ProjectSettings
    var mediaRegistry: [MediaReference]
    var compositionRegistry: [ProjectComposition]
    var layerRegistry: [ProjectLayer]
    var aiAssetRegistry: [ProjectAIAsset]
    var activeCompositionID: VertexID?
    var selectedLayerID: VertexID?
    var selectedMediaID: VertexID?
}

enum Schema4ProjectCodec {
    static func decode(_ data: Data) throws -> Schema4ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ProjectDateCodec.decode)
        decoder.nonConformingFloatDecodingStrategy = .throw
        do {
            let value = try decoder.decode(Schema4ProjectDocument.self, from: data)
            guard value.schemaVersion == 4 else {
                throw ProjectError.migrationFailure("Schema 4 compatibility decoder received schema \(value.schemaVersion).")
            }
            guard value.minimumReaderVersion <= 4 else {
                throw ProjectError.migrationFailure("Schema 4 minimum reader version is invalid.")
            }
            return value
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.decodingFailure("Schema 4 project could not be decoded: \(error.localizedDescription)")
        }
    }

    static func encode(_ document: Schema4ProjectDocument) throws -> Data {
        guard document.schemaVersion == 4 else {
            throw ProjectError.migrationFailure("Schema 4 compatibility encoder requires schema 4.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom(ProjectDateCodec.encode)
        encoder.nonConformingFloatEncodingStrategy = .throw
        do {
            return try encoder.encode(document)
        } catch {
            throw ProjectError.deterministicEncodingFailure("Schema 4 project could not be encoded: \(error.localizedDescription)")
        }
    }
}

public struct Schema4To5Migrator: ProjectMigrator {
    public let sourceVersion = 4
    public let destinationVersion = 5

    public init() {}

    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult {
        let legacy = try Schema4ProjectCodec.decode(data)
        var metadata = legacy.metadata
        metadata.lastSavedByAppVersion = "9.0.0"
        var layers = legacy.layerRegistry
        for index in layers.indices {
            layers[index].timing.sourceOffset = .zero
            layers[index].parentLayerID = nil
        }
        var compositions = legacy.compositionRegistry
        for index in compositions.indices {
            compositions[index].workArea = nil
            compositions[index].markers = []
        }

        let migrated = try ProjectDocument(
            schemaVersion: 5,
            minimumReaderVersion: 5,
            projectID: legacy.projectID,
            revision: legacy.revision,
            metadata: metadata,
            settings: legacy.settings,
            mediaRegistry: legacy.mediaRegistry,
            compositionRegistry: compositions,
            layerRegistry: layers,
            aiAssetRegistry: legacy.aiAssetRegistry,
            activeCompositionID: legacy.activeCompositionID,
            selectedLayerID: legacy.selectedLayerID,
            selectedMediaID: legacy.selectedMediaID
        ).validated()

        return ProjectMigrationStepResult(
            data: try DeterministicProjectCodec().encode(migrated),
            report: ProjectMigrationReport(
                sourceVersion: 4,
                destinationVersion: 5,
                messages: [
                    "Added exact source offsets, parent links, work areas, and markers with deterministic empty defaults.",
                    "Preserved schema 4 media, layers, masks, mattes, animation channels, AI assets, selection, revision, and composition order."
                ]
            )
        )
    }
}
''')

# Register 4 -> 5 migration.
replace_once(
    "Sources/VertexProject/ProjectMigration.swift",
    "        Schema2To3Migrator(),\n        Schema3To4Migrator()\n",
    "        Schema2To3Migrator(),\n        Schema3To4Migrator(),\n        Schema4To5Migrator()\n",
)

# Keep schema3->4 independently encodable when current schema advances to 5.
s34 = read("Sources/VertexProject/Schema3To4Migrator.swift")
if "Schema4ProjectCodec.encode" not in s34:
    old = '''        let migrated = try ProjectDocument(\n            schemaVersion: 4,\n            minimumReaderVersion: 4,\n            projectID: legacy.projectID,\n            revision: legacy.revision,\n            metadata: metadata,\n            settings: legacy.settings,\n            mediaRegistry: legacy.mediaRegistry,\n            compositionRegistry: legacy.compositionRegistry,\n            layerRegistry: layers,\n            aiAssetRegistry: legacy.aiAssetRegistry,\n            activeCompositionID: legacy.activeCompositionID,\n            selectedLayerID: legacy.selectedLayerID,\n            selectedMediaID: legacy.selectedMediaID\n        ).validated()\n\n        return ProjectMigrationStepResult(\n            data: try DeterministicProjectCodec().encode(migrated),'''
    new = '''        let migrated = Schema4ProjectDocument(\n            schemaVersion: 4,\n            minimumReaderVersion: 4,\n            projectID: legacy.projectID,\n            revision: legacy.revision,\n            metadata: metadata,\n            settings: legacy.settings,\n            mediaRegistry: legacy.mediaRegistry,\n            compositionRegistry: legacy.compositionRegistry,\n            layerRegistry: layers,\n            aiAssetRegistry: legacy.aiAssetRegistry,\n            activeCompositionID: legacy.activeCompositionID,\n            selectedLayerID: legacy.selectedLayerID,\n            selectedMediaID: legacy.selectedMediaID\n        )\n\n        return ProjectMigrationStepResult(\n            data: try Schema4ProjectCodec.encode(migrated),'''
    if old not in s34:
        raise RuntimeError("Schema3To4 migration marker not found")
    write("Sources/VertexProject/Schema3To4Migrator.swift", s34.replace(old, new, 1))

# Focused tests.
write("Tests/VertexProjectTests/ProjectTimelineSchemaTests.swift", r'''import Testing
import VertexCore
@testable import VertexProject

@Suite("Schema 5 timeline primitives")
struct ProjectTimelineSchemaTests {
    @Test func layerTimingSeparatesCompositionPlacementFromSourceOffset() throws {
        let timing = LayerTiming(
            startTime: RationalTime(value: 30, timescale: 30),
            inPoint: RationalTime(value: 30, timescale: 30),
            outPoint: RationalTime(value: 90, timescale: 30),
            sourceOffset: RationalTime(value: 15, timescale: 30)
        )
        #expect(timing.startTime == RationalTime(value: 1, timescale: 1))
        #expect(timing.sourceOffset == RationalTime(value: 1, timescale: 2))
    }

    @Test func workAreaRequiresOrderedCompositionTimes() throws {
        #expect(throws: ProjectError.self) {
            _ = try ProjectWorkArea(
                start: RationalTime(value: 5, timescale: 1),
                end: RationalTime(value: 4, timescale: 1)
            ).validated(compositionDuration: RationalTime(value: 10, timescale: 1))
        }
    }

    @Test func markerMustRemainInsideComposition() throws {
        #expect(throws: ProjectError.self) {
            _ = try ProjectMarker(
                time: RationalTime(value: 10, timescale: 1),
                name: "End"
            ).validated(compositionDuration: RationalTime(value: 10, timescale: 1))
        }
    }

    @Test func parentCycleIsRejected() throws {
        var document = try ProjectDocument.makeNew(name: "Parent cycle")
        let composition = try #require(document.compositionRegistry.first)
        let timing = LayerTiming(startTime: .zero, inPoint: .zero, outPoint: RationalTime(value: 5, timescale: 1))
        let aID = VertexID(rawValue: "91000000-0000-0000-0000-000000000001")
        let bID = VertexID(rawValue: "91000000-0000-0000-0000-000000000002")
        let a = ProjectLayer(id: aID, compositionID: composition.id, name: "A", source: .null, timing: timing, parentLayerID: bID)
        let b = ProjectLayer(id: bID, compositionID: composition.id, name: "B", source: .null, timing: timing, parentLayerID: aID)
        document.layerRegistry = [a, b]
        document.compositionRegistry[0].layerIDs = [aID, bID]
        #expect(throws: ProjectError.self) { _ = try document.validated() }
    }
}
''')

write("Tests/VertexProjectTests/Schema4To5MigrationTests.swift", r'''import Foundation
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
            }
            root["compositionRegistry"] = compositions
        }
        let schema4Data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        let result = try ProjectMigrationRegistry.current.migrate(schema4Data, from: 4, to: 5)
        let migrated = try DeterministicProjectCodec().decode(result.data)
        #expect(migrated.schemaVersion == 5)
        #expect(migrated.metadata.lastSavedByAppVersion == "9.0.0")
        #expect(migrated.compositionRegistry.allSatisfy { $0.workArea == nil && $0.markers.isEmpty })
        #expect(migrated.layerRegistry.allSatisfy { $0.timing.sourceOffset == .zero && $0.parentLayerID == nil })
    }
}
''')

print("Task 1 applied")
