# Phase 6 Layers and Compositions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build schema 2 composition and layer persistence, real multi-source Metal compositing with four blend modes, adjustment layers, basic nested compositions, and a functional exact-frame layer workspace, then publish the verified unsigned `6.0.0 (6)` IPA.

**Architecture:** `VertexProject` owns portable schema 2 values, migrations, commands, and history. A new platform-neutral `VertexComposition` module compiles one project composition at an exact `RationalTime` into the extended multi-source `VertexRender` DAG, and `VertexRenderMetal` evaluates that DAG with premultiplied-alpha layer, composite, adjustment, and solid-background pipelines. The app remains the only place that resolves package URLs, security-scoped media, AVFoundation frames, SwiftUI state, and project-package migration destinations.

**Tech Stack:** Swift 6.0, Swift Testing, Swift Package Manager, XcodeGen, SwiftUI, AVFoundation adapters, Foundation file coordination, Metal compute shaders, GitHub Actions, iOS 17, macOS 14.

## Global Constraints

- Work only on `agent/phase-6-layers-compositions`, based on `agent/phase-5-project-persistence`.
- Keep Draft PR #6 stacked on Phase 5; do not merge automatically.
- Successful app version is exactly `6.0.0 (6)`.
- Successful artifact is exactly `After-Effects-6.0.0-unsigned.ipa`.
- Project schema becomes exactly `2`; schema 1 packages migrate non-destructively.
- Keep iOS deployment target `17.0`, macOS package floor `14`, and Swift language version `6.0`.
- Preview and PNG output must consume the same `RenderResult.image` bytes.
- Project and compiler models may not expose AVFoundation, Metal, UIKit, SwiftUI, security-scoped URL objects, file descriptors, or absolute sandbox paths.
- All project time remains exact `RationalTime`; UI `Double` values are converted immediately to exact frame indices.
- Composition size is at most `8192 × 8192`, stored layers are at most `256` per composition, nested depth is at most `16`, and expanded render nodes are at most `4096`.
- Schema 2 writes only `normal`, `add`, `multiply`, and `screen`; planned blend modes are not selectable or serializable.
- Null, guide, camera, and light are model-only in Phase 6 and may not change visible output.
- Continuous playback, full NLE timeline behavior, keyframes, parenting, motion blur, retiming, advanced pre-composition, camera/light rendering, video export, masks, tracking, AI, shapes, text, professional color/audio, particles, nodes, and 3D remain excluded.
- No new external source dependency is introduced.
- Every production change follows RED → GREEN → regression verification → focused commit.

## File Map

### New portable project files

- `Sources/VertexProject/ProjectRGBAColor.swift`: finite normalized project color value.
- `Sources/VertexProject/ProjectComposition.swift`: composition record, dimensions, timing, Z-order, and validation.
- `Sources/VertexProject/ProjectLayer.swift`: layer source, transform, operations, blend mode, camera/light records, and validation.
- `Sources/VertexProject/DeterministicVertexID.swift`: SHA-256-derived RFC 4122 stable IDs.
- `Sources/VertexProject/Schema1Compatibility.swift`: private schema 1 document, command, history, manifest, and journal DTOs used only for migration.
- `Sources/VertexProject/Schema1To2Migrator.swift`: deterministic raw schema migration.

### New composition compiler files

- `Sources/VertexComposition/CompositionError.swift`: structured compiler errors.
- `Sources/VertexComposition/CompositionTypes.swift`: request, limits, frame resolution, and resolver protocol.
- `Sources/VertexComposition/CompositionVisibility.swift`: enabled, timing, Solo, and model-only filtering.
- `Sources/VertexComposition/CompositionGraphCompiler.swift`: exact-time recursive project-to-render compilation.
- `Sources/VertexComposition/CompositionModule.swift`: module identity and public guarantees.
- `Tests/VertexCompositionTests/CompositionVisibilityTests.swift`
- `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`
- `Tests/VertexCompositionTests/CompositionLimitsTests.swift`

### New Metal execution files

- `Sources/VertexRenderMetal/MetalGraphExecutor.swift`: topological DAG execution and texture last-use tracking.
- `Sources/VertexRenderMetal/MetalTexturePool.swift`: bounded compatible texture reuse.
- `Sources/VertexRenderMetal/MetalRenderParameters.swift`: Swift/Metal parameter layouts for solid, layer, composite, and adjustment kernels.

### New app files

- `App/CompositionMediaFrameResolver.swift`: embedded/bookmark URL resolution and exact AVFoundation frame adapter.
- `App/CompositionPreviewController.swift`: latest-request rendering, last-success retention, and exact frame state.
- `App/ProjectWorkspaceCompositionCommands.swift`: durable composition/layer operations on the existing workspace.
- `App/CompositionWorkspaceView.swift`: integrated composition editor surface.
- `App/CompositionHeaderView.swift`
- `App/ExactFrameNavigatorView.swift`
- `App/LayerListView.swift`
- `App/LayerInspectorView.swift`

### Existing files with focused modifications

- `Package.swift`
- `project.yml`
- `Sources/VertexProject/ProjectSchema.swift`
- `Sources/VertexProject/ProjectCommands.swift`
- `Sources/VertexProject/ProjectHistory.swift`
- `Sources/VertexProject/ProjectMigration.swift`
- `Sources/VertexProject/ProjectError.swift`
- `Sources/VertexProject/ProjectModule.swift`
- `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- `Sources/VertexProjectFoundation/ProjectRecovery.swift`
- `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`
- `Sources/VertexRender/RenderTypes.swift`
- `Sources/VertexRender/RenderGraph.swift`
- `Sources/VertexRender/RenderError.swift`
- `Sources/VertexRenderMetal/MetalRenderResources.swift`
- `Sources/VertexRenderMetal/MetalRenderBackend.swift`
- `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- `App/ProjectWorkspaceViewModel.swift`
- `App/ProjectWorkspaceView.swift`
- `App/MediaImportView.swift`
- `App/RootView.swift`
- `Sources/VertexCore/Milestone.swift`
- `.github/workflows/phase-build.yml`
- `README.md`
- Phase 6 architecture, test, completion, work-log, versioning, and handoff documents.

---

### Task 1: Schema 2 Composition and Layer Values

**Files:**
- Create: `Sources/VertexProject/ProjectRGBAColor.swift`
- Create: `Sources/VertexProject/ProjectComposition.swift`
- Create: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Modify: `Sources/VertexProject/ProjectError.swift`
- Test: `Tests/VertexProjectTests/ProjectCompositionSchemaTests.swift`
- Test: `Tests/VertexProjectTests/ProjectCodecTests.swift`

**Interfaces:**
- Produces: `ProjectRGBAColor`, `ProjectComposition`, `ProjectLayer`, `LayerSource`, `LayerTransform`, `LayerOperation`, `LayerBlendMode`, `LayerTiming`, `CameraLayerSettings`, `LightLayerSettings`, and schema 2 `ProjectDocument` lookup/validation helpers.
- Consumes: `VertexID`, `RationalTime`, `ColorDescriptor`, `MediaReference`, and the existing deterministic codec.

- [ ] **Step 1: Write schema 2 RED tests**

Create tests that instantiate two compositions and four layer types, then assert canonical registry order, preserved Z-order, ownership validation, timing boundaries, source references, model-only restrictions, and direct/indirect nested-cycle rejection.

```swift
import Foundation
import Testing
import VertexCore
@testable import VertexProject

@Test("Schema 2 canonicalization preserves authoritative layer Z-order")
func schema2PreservesLayerOrder() throws {
    let media = MediaReference.fixture()
    let composition = try ProjectComposition.fixture(
        id: "60000000-0000-0000-0000-000000000001",
        layerIDs: [
            VertexID(rawValue: "60000000-0000-0000-0000-000000000012"),
            VertexID(rawValue: "60000000-0000-0000-0000-000000000011")
        ]
    )
    let top = try ProjectLayer.mediaFixture(
        id: "60000000-0000-0000-0000-000000000012",
        compositionID: composition.id,
        mediaID: media.id,
        name: "Top"
    )
    let bottom = try ProjectLayer.mediaFixture(
        id: "60000000-0000-0000-0000-000000000011",
        compositionID: composition.id,
        mediaID: media.id,
        name: "Bottom"
    )
    let document = try ProjectDocument.makeFixture(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        media: [media],
        compositions: [composition],
        layers: [top, bottom],
        activeCompositionID: composition.id
    )

    let decoded = try DeterministicProjectCodec().decode(
        DeterministicProjectCodec().encode(document)
    )
    #expect(decoded.schemaVersion == 2)
    #expect(decoded.composition(id: composition.id)?.layerIDs == composition.layerIDs)
    #expect(decoded.layerRegistry.map(\.id) == [bottom.id, top.id])
}

@Test("Nested composition cycles are rejected persistently")
func nestedCyclesAreRejected() throws {
    let fixture = try ProjectDocument.cyclicCompositionFixture()
    #expect(throws: ProjectError.self) { try fixture.validated() }
}
```

- [ ] **Step 2: Run the RED tests**

Run:

```bash
swift test --filter ProjectCompositionSchemaTests
```

Expected: compile failure because schema 2 types and helpers do not exist.

- [ ] **Step 3: Implement exact portable value types**

Use these final public shapes:

```swift
public struct ProjectRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public func validated() throws -> Self
}

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
    public func validated(layerByID: [VertexID: ProjectLayer]) throws -> Self
}

public enum LayerBlendMode: String, Codable, CaseIterable, Sendable {
    case normal, add, multiply, screen
}

public struct LayerTransform: Codable, Equatable, Sendable {
    public var positionX: Double
    public var positionY: Double
    public var anchorX: Double
    public var anchorY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
    public var opacity: Double
    public static let identity: LayerTransform
    public func validated() throws -> Self
}

public struct LayerTiming: Codable, Equatable, Sendable {
    public var startTime: RationalTime
    public var inPoint: RationalTime
    public var outPoint: RationalTime
    public func validated(for composition: ProjectComposition) throws -> Self
}

public enum LayerOperation: Codable, Equatable, Sendable {
    case exposure(stops: Double)
    case saturation(value: Double)
    case invert(enabled: Bool)
    public func validated() throws -> Self
}

public enum LayerSource: Codable, Equatable, Sendable {
    case media(mediaID: VertexID, sourceStartTime: RationalTime)
    case adjustment(scope: AdjustmentScope)
    case null
    case guide
    case camera(CameraLayerSettings)
    case light(LightLayerSettings)
    case composition(compositionID: VertexID, sourceStartTime: RationalTime)
}

public struct ProjectLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var compositionID: VertexID
    public var name: String
    public var source: LayerSource
    public var enabled: Bool
    public var locked: Bool
    public var solo: Bool
    public var timing: LayerTiming
    public var transform: LayerTransform
    public var blendMode: LayerBlendMode
    public var operations: [LayerOperation]
    public func validated(in document: ProjectDocument) throws -> Self
}
```

Implement camera and light fields exactly as approved in the design, including finite-value and range checks. Enforce `normal` plus empty operations for null, guide, camera, and light, and `normal` for adjustment layers.

- [ ] **Step 4: Upgrade `ProjectDocument` to schema 2**

Set:

```swift
public static let currentSchemaVersion = 2
public static let currentAppVersion = "6.0.0"
```

Replace placeholder composition storage with:

```swift
public var compositionRegistry: [ProjectComposition]
public var layerRegistry: [ProjectLayer]
public var activeCompositionID: VertexID?
public var selectedLayerID: VertexID?
public var selectedMediaID: VertexID?
public var legacyRenderSettings: ProjectRenderSettings?
```

Add exact helpers:

```swift
public func composition(id: VertexID) -> ProjectComposition?
public func layer(id: VertexID) -> ProjectLayer?
public func layers(in compositionID: VertexID) -> [ProjectLayer]
public func nestedCompositionCycle() -> [VertexID]?
```

`normalized()` sorts registries and applied command IDs by ID but never sorts `ProjectComposition.layerIDs`. `validated()` checks unique IDs, ownership, active/selected identities, source references, timing, transforms, model-only restrictions, and nested cycles.

- [ ] **Step 5: Run schema and codec tests**

Run:

```bash
swift test --filter ProjectCompositionSchemaTests
swift test --filter ProjectCodecTests
```

Expected: all schema 2 and existing deterministic codec tests pass.

- [ ] **Step 6: Commit schema 2 values**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add schema 2 composition and layer values"
```

---

### Task 2: Deterministic Schema 1 to Schema 2 Migration

**Files:**
- Create: `Sources/VertexProject/DeterministicVertexID.swift`
- Create: `Sources/VertexProject/Schema1Compatibility.swift`
- Create: `Sources/VertexProject/Schema1To2Migrator.swift`
- Modify: `Sources/VertexProject/ProjectMigration.swift`
- Test: `Tests/VertexProjectTests/ProjectSchemaMigrationTests.swift`
- Test fixture: `Tests/VertexProjectTests/Fixtures/schema1-selected-media.json`
- Test fixture: `Tests/VertexProjectTests/Fixtures/schema1-no-composition.json`

**Interfaces:**
- Consumes: schema 2 types from Task 1 and canonical date/JSON codecs.
- Produces: `DeterministicVertexID.derive(domain:components:)`, `Schema1ProjectSnapshot`, `Schema1JournalReplayer`, and `Schema1To2Migrator` registered in `ProjectMigrationRegistry.current`.

- [ ] **Step 1: Add migration RED tests and frozen schema 1 fixtures**

```swift
@Test("Schema 1 migration is deterministic and transfers selected media settings")
func schema1SelectedMediaMigratesDeterministically() throws {
    let input = try Fixture.data("schema1-selected-media.json")
    let registry = ProjectMigrationRegistry.current
    let first = try registry.migrate(input, from: 1, to: 2)
    let second = try registry.migrate(input, from: 1, to: 2)
    #expect(first.data == second.data)

    let project = try DeterministicProjectCodec().decode(first.data)
    #expect(project.schemaVersion == 2)
    #expect(project.layerRegistry.count == 1)
    #expect(project.layerRegistry[0].transform.opacity == 0.75)
    #expect(project.layerRegistry[0].operations.contains(.exposure(stops: 1.25)))
    #expect(project.legacyRenderSettings == nil)
}

@Test("Schema 1 without selected media preserves legacy settings without a fake layer")
func schema1WithoutSelectionPreservesLegacySettings() throws {
    let input = try Fixture.data("schema1-no-composition.json")
    let result = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let project = try DeterministicProjectCodec().decode(result.data)
    #expect(project.compositionRegistry.count == 1)
    #expect(project.layerRegistry.isEmpty)
    #expect(project.legacyRenderSettings != nil)
}
```

- [ ] **Step 2: Run migration tests to verify RED**

```bash
swift test --filter ProjectSchemaMigrationTests
```

Expected: failure because no 1→2 migrator or compatibility DTO exists.

- [ ] **Step 3: Implement stable ID derivation**

```swift
public enum DeterministicVertexID {
    public static func derive(domain: String, components: [String]) -> VertexID {
        let payload = ([domain] + components).joined(separator: "\u{1f}")
        var bytes = Array(StableProjectSHA256.digest(Data(payload.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return VertexID(uuidBytes: bytes)
    }
}
```

Expose raw SHA-256 digest bytes from `StableProjectSHA256` and add a checked `VertexID(uuidBytes:)` initializer in `VertexCore` if needed. Test fixed domain/component vectors against exact expected IDs.

- [ ] **Step 4: Freeze private schema 1 DTOs**

In `Schema1Compatibility.swift`, copy the schema 1 wire shape into types prefixed `Schema1`, including project document, render settings, composition placeholder, operation, command record, history, manifest, and journal record. These types are migration-only and are not exported as current writable project state.

Implement:

```swift
struct Schema1RecoveredState: Sendable {
    var document: Schema1ProjectDocument
    var lastJournalSequence: UInt64
}

struct Schema1JournalReplayer {
    func replay(
        _ records: [Schema1JournalRecord],
        onto document: Schema1ProjectDocument,
        startingAfter sequence: UInt64
    ) throws -> Schema1RecoveredState
}
```

The replay engine supports every Phase 5 operation and keeps its exact preconditions.

- [ ] **Step 5: Implement `Schema1To2Migrator`**

```swift
public struct Schema1To2Migrator: ProjectMigrator {
    public let sourceVersion = 1
    public let destinationVersion = 2
    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult
}
```

Use old placeholder IDs when present. Derive `Main Composition` and selected-media layer IDs with explicit domains. Use ten exact seconds, old output dimensions, project frame rate/color, transparent background, and full composition In/Out. Move old global settings into the selected media layer or `legacyRenderSettings` exactly as specified.

Register it:

```swift
public static let current = ProjectMigrationRegistry(
    migrators: [Schema1To2Migrator()]
)
```

- [ ] **Step 6: Run migration and full project tests**

```bash
swift test --filter ProjectSchemaMigrationTests
swift test --filter VertexProjectTests
```

Expected: deterministic migration and all project tests pass.

- [ ] **Step 7: Commit migration**

```bash
git add Sources/VertexCore Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add deterministic schema 1 to 2 migration"
```

---

### Task 3: Composition and Layer Commands with Undo/Redo

**Files:**
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectHistory.swift`
- Create: `Sources/VertexProject/ProjectCommandPayloads.swift`
- Test: `Tests/VertexProjectTests/ProjectCompositionCommandTests.swift`
- Test: `Tests/VertexProjectTests/ProjectLayerCommandTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectCommandTests.swift`

**Interfaces:**
- Consumes: validated schema 2 values.
- Produces: reversible composition/layer `ProjectOperation` cases and generic coalescing for exact chained before/after values.

- [ ] **Step 1: Add command RED tests**

Cover create, duplicate, remove, rename, dimensions, duration, frame rate, background, active composition, insert/remove/duplicate/reorder layer, selection, enabled/locked/solo, timing, transform, blend, source, operations, camera, and light.

```swift
@Test("Layer reorder undo restores the exact original index")
func layerReorderUndoRestoresIndex() throws {
    let fixture = try ProjectDocument.layerCommandFixture()
    let controller = try ProjectHistoryController(project: fixture.document)
    try controller.perform(.reorderLayer(
        compositionID: fixture.composition.id,
        layerID: fixture.bottom.id,
        beforeIndex: 1,
        afterIndex: 0
    ))
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs[0] == fixture.bottom.id)
    _ = try controller.undo()
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Referenced nested composition deletion is rejected without revision change")
func referencedCompositionCannotBeRemoved() throws {
    let fixture = try ProjectDocument.nestedCommandFixture()
    let record = ProjectCommandRecord(
        project: fixture.document,
        operation: .removeComposition(
            composition: fixture.child,
            ownedLayers: [],
            previousActiveID: fixture.parent.id,
            previousSelection: nil
        )
    )
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().apply(record, to: fixture.document)
    }
}
```

- [ ] **Step 2: Run RED command tests**

```bash
swift test --filter ProjectCompositionCommandTests
swift test --filter ProjectLayerCommandTests
```

Expected: compile failure on missing operation cases.

- [ ] **Step 3: Add exact payload values and operation cases**

Define payloads such as:

```swift
public struct CompositionInsertionContext: Codable, Equatable, Sendable {
    public var registryIndex: Int
}

public enum ProjectOperation: Codable, Equatable, Sendable {
    case renameProject(before: String, after: String)
    case registerMedia(MediaReference)
    case removeMedia(MediaReference)
    case relinkMedia(mediaID: VertexID, before: MediaLocator, after: MediaLocator)
    case setEmbeddedPath(mediaID: VertexID, before: String?, after: String?)
    case selectMedia(before: VertexID?, after: VertexID?)

    case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], insertion: CompositionInsertionContext)
    case removeComposition(ProjectComposition, ownedLayers: [ProjectLayer], previousActiveID: VertexID?, previousSelection: VertexID?)
    case duplicateComposition(sourceID: VertexID, composition: ProjectComposition, layers: [ProjectLayer], insertion: CompositionInsertionContext)
    case renameComposition(compositionID: VertexID, before: String, after: String)
    case setActiveComposition(before: VertexID?, after: VertexID?)
    case setCompositionDimensions(compositionID: VertexID, beforeWidth: Int, beforeHeight: Int, afterWidth: Int, afterHeight: Int)
    case setCompositionDuration(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionFrameRate(compositionID: VertexID, before: RationalTime, after: RationalTime)
    case setCompositionBackground(compositionID: VertexID, before: ProjectRGBAColor, after: ProjectRGBAColor)

    case insertLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case removeLayer(ProjectLayer, compositionID: VertexID, index: Int)
    case duplicateLayer(sourceLayerID: VertexID, duplicate: ProjectLayer, compositionID: VertexID, index: Int)
    case renameLayer(layerID: VertexID, before: String, after: String)
    case reorderLayer(compositionID: VertexID, layerID: VertexID, beforeIndex: Int, afterIndex: Int)
    case setSelectedLayer(before: VertexID?, after: VertexID?)
    case setLayerEnabled(layerID: VertexID, before: Bool, after: Bool)
    case setLayerLocked(layerID: VertexID, before: Bool, after: Bool)
    case setLayerSolo(layerID: VertexID, before: Bool, after: Bool)
    case setLayerTiming(layerID: VertexID, before: LayerTiming, after: LayerTiming)
    case setLayerTransform(layerID: VertexID, before: LayerTransform, after: LayerTransform)
    case setLayerBlendMode(layerID: VertexID, before: LayerBlendMode, after: LayerBlendMode)
    case setLayerSource(layerID: VertexID, before: LayerSource, after: LayerSource)
    case setLayerOperations(layerID: VertexID, before: [LayerOperation], after: [LayerOperation])
}
```

Implement exact `inverse`, preconditions, ownership checks, referenced-composition deletion refusal, and full-document validation before returning.

- [ ] **Step 4: Extend history coalescing**

Coalesce chained `setLayerTransform`, `setLayerTiming`, and `setLayerOperations` records only when project/layer, merge key, time interval, and `previous.after == current.before` all match. Keep blend changes independent because they use no merge key.

- [ ] **Step 5: Verify journal-before-mutation remains true**

Add tests where `undo(prepare:)` and `redo(prepare:)` throw. Assert project bytes, layer order, selection, and history counts remain identical.

- [ ] **Step 6: Run command, history, journal, and codec suites**

```bash
swift test --filter VertexProjectTests
```

Expected: all project tests pass.

- [ ] **Step 7: Commit commands**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add composition and layer commands"
```

---

### Task 4: Non-Destructive Package Migration and Schema 2 Recovery

**Files:**
- Create: `Sources/VertexProjectFoundation/ProjectPackageMigrator.swift`
- Create: `Sources/VertexProjectFoundation/Schema1PackageReader.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectRecovery.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`
- Test: `Tests/VertexProjectFoundationTests/ProjectPackageMigrationTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectPackageStoreTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectRecoveryTests.swift`

**Interfaces:**
- Consumes: schema 1 compatibility/replay and schema 2 migrator.
- Produces: a non-destructive package opening service that returns either an existing schema 2 package or a newly created schema 2 working package with empty history/journal and retained recovered revision.

- [ ] **Step 1: Add package migration RED tests**

```swift
@Test("Opening schema 1 creates a separate schema 2 package and leaves source bytes unchanged")
func packageMigrationIsNonDestructive() throws {
    let fixture = try Schema1PackageFixture.make()
    let sourceBefore = try fixture.snapshotBytes()
    let destination = fixture.root.appendingPathComponent("Migrated.aeproject")

    let result = try ProjectPackageMigrator().migrate(
        schema1PackageURL: fixture.packageURL,
        destinationURL: destination
    )

    #expect(result.loadResult.document.schemaVersion == 2)
    #expect(result.loadResult.document.revision == fixture.recoveredRevision)
    #expect(result.loadResult.history == ProjectHistorySnapshot())
    #expect(result.loadResult.manifest.committedJournalSequence == 0)
    #expect(try fixture.snapshotBytes() == sourceBefore)
}
```

Also inject a destination write failure and verify no authoritative migrated package is published.

- [ ] **Step 2: Run package migration tests to verify RED**

```bash
swift test --filter ProjectPackageMigrationTests
```

Expected: compile failure because package migrator does not exist.

- [ ] **Step 3: Implement `Schema1PackageReader`**

Read schema 1 `project.json`, manifest, history, and journal with migration-only DTOs. Verify the schema 1 project checksum and identity, analyze complete journal lines, replay records newer than the committed sequence, and return one recovered logical snapshot. Do not mutate source package files.

- [ ] **Step 4: Implement `ProjectPackageMigrator`**

```swift
public struct ProjectPackageMigrationResult: Sendable {
    public var sourcePackageURL: URL
    public var migratedPackageURL: URL
    public var reports: [ProjectMigrationReport]
    public var loadResult: ProjectPackageLoadResult
}

public struct ProjectPackageMigrator {
    public func migrate(
        schema1PackageURL: URL,
        destinationURL: URL
    ) throws -> ProjectPackageMigrationResult
}
```

Migration sequence:

```text
read and verify schema 1 package
→ replay valid pending schema 1 journal
→ canonical encode recovered schema 1 snapshot
→ run 1→2 migrator
→ decode and validate schema 2
→ create destination package with empty history and journal sequence 0
→ read back and checksum-verify destination
→ return result
```

Remove a partially written destination on failure while preserving the source.

- [ ] **Step 5: Make package loading schema-aware**

Add:

```swift
public enum ProjectPackageOpenResult: Sendable {
    case opened(ProjectPackageLoadResult)
    case migrated(ProjectPackageMigrationResult)
}

public struct ProjectPackageOpeningService {
    public func open(
        packageURL: URL,
        migrationDestination: @Sendable () throws -> URL
    ) throws -> ProjectPackageOpenResult
}
```

Inspect the root schema header before current decode. Open schema 2 directly, migrate schema 1, and reject future schemas without rewriting.

- [ ] **Step 6: Extend autosave and recovery schema 2 regression tests**

Verify layer ownership and Z-order survive save/reopen, autosave rotation, current corruption with backup recovery, and recovered-package creation. A backup with mismatched history still opens with empty history.

- [ ] **Step 7: Run Foundation tests**

```bash
swift test --filter VertexProjectFoundationTests
```

Expected: package migration and all Phase 5 persistence regressions pass.

- [ ] **Step 8: Commit package migration**

```bash
git add Sources/VertexProjectFoundation Tests/VertexProjectFoundationTests
git commit -m "feat: migrate project packages to schema 2"
```

---

### Task 5: Multi-Source `VertexRender` DAG

**Files:**
- Create: `Sources/VertexRender/RenderBlendMode.swift`
- Modify: `Sources/VertexRender/RenderTypes.swift`
- Modify: `Sources/VertexRender/RenderGraph.swift`
- Modify: `Sources/VertexRender/RenderError.swift`
- Test: `Tests/VertexRenderTests/RenderGraphTests.swift`
- Test: `Tests/VertexRenderTests/RenderMultiSourceTests.swift`
- Modify: `Tests/VertexRenderTests/RenderSchedulingTests.swift`

**Interfaces:**
- Produces: ordered multi-source graph evaluation with local operations, solid-color background source, composite and adjustment nodes.
- Consumes: portable images, exact time, output descriptor, and existing cancellation/cache primitives.

- [ ] **Step 1: Add multi-source graph RED tests**

```swift
@Test("Composite dependency order remains backdrop then source")
func compositeDependencyOrderIsSemantic() throws {
    let graph = try RenderGraph.twoSourceFixture(blendMode: .multiply)
    let plan = try graph.evaluationPlan()
    let composite = try #require(plan.orderedNodes.first { node in
        if case .composite = node.kind { return true }
        return false
    })
    #expect(composite.dependencies == [RenderGraph.fixtureBackdropID, RenderGraph.fixtureSourceID])
}

@Test("Disconnected nodes are rejected")
func disconnectedNodesFail() throws {
    #expect(throws: RenderError.self) {
        try RenderGraph.disconnectedFixture().evaluationPlan()
    }
}
```

- [ ] **Step 2: Run RED render tests**

```bash
swift test --filter RenderMultiSourceTests
```

Expected: compile failure on missing blend/source/composite types.

- [ ] **Step 3: Implement final render graph values**

Use:

```swift
public struct RenderRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public func validated() throws -> Self
}

public enum RenderSource: Codable, Equatable, Sendable {
    case image(PortableImage)
    case solidColor(RenderRGBAColor)
}

public enum RenderBlendMode: String, Codable, CaseIterable, Sendable {
    case normal, add, multiply, screen
}

public struct RenderTransform2D: Codable, Equatable, Sendable {
    public var positionX: Double
    public var positionY: Double
    public var anchorX: Double
    public var anchorY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
}

public enum RenderOperation: Codable, Equatable, Sendable {
    case transform2D(RenderTransform2D)
    case exposure(stops: Double)
    case saturation(Double)
    case invert(Bool)
    case opacity(Double)
}

public enum RenderNodeKind: Codable, Equatable, Sendable {
    case source(RenderSource)
    case operations([RenderOperation])
    case composite(RenderBlendMode)
    case adjustment([RenderOperation], mix: Double)
    case output
}
```

`solidColor` is the backend-neutral implementation of the design's deterministic transparent/colored background source and avoids platform PNG encoding in `VertexComposition`.

- [ ] **Step 4: Replace single-source flattening with an evaluation plan**

```swift
public struct RenderEvaluationPlan: Equatable, Sendable {
    public var orderedNodes: [RenderNode]
    public var outputNodeID: VertexID
    public var consumerCounts: [VertexID: Int]
}

public func evaluationPlan() throws -> RenderEvaluationPlan
```

Require one output, allow multiple sources, preserve dependency order, reject duplicate/missing/disconnected/cyclic nodes, and validate node arity and local operations. Remove backend use of `sourceImage()` and `flattenedOperations()`; retain deprecated helpers only until Task 7 is green, then delete them.

- [ ] **Step 5: Extend metrics and cache context**

Add `expandedNodeCount`, `renderedLayerCount`, and `estimatedPeakTextureBytes` to `RenderMetrics`. Add an optional deterministic `context: RenderCacheContext` to `RenderRequest`, containing composition ID, project revision, and compiler version, while graph bytes, exact time, and output remain encoded in the cache key.

- [ ] **Step 6: Run render tests**

```bash
swift test --filter VertexRenderTests
```

Expected: all graph, cache, cancellation, validation, and preview/output payload tests pass.

- [ ] **Step 7: Commit render DAG**

```bash
git add Sources/VertexRender Tests/VertexRenderTests
git commit -m "feat: extend render graph for multi-source composition"
```

---

### Task 6: `VertexComposition` Compiler

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Create: `Sources/VertexComposition/CompositionError.swift`
- Create: `Sources/VertexComposition/CompositionTypes.swift`
- Create: `Sources/VertexComposition/CompositionVisibility.swift`
- Create: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Create: `Sources/VertexComposition/CompositionModule.swift`
- Create: `Tests/VertexCompositionTests/CompositionVisibilityTests.swift`
- Create: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`
- Create: `Tests/VertexCompositionTests/CompositionLimitsTests.swift`

**Interfaces:**
- Consumes: schema 2 project values and Task 5 render graph.
- Produces: exact asynchronous `CompositionGraphCompiler.compile` and platform-free frame resolution.

- [ ] **Step 1: Wire an empty product/target and add RED tests**

Add package products/targets:

```swift
.library(name: "VertexComposition", targets: ["VertexComposition"])
.target(
    name: "VertexComposition",
    dependencies: ["VertexCore", "VertexMedia", "VertexProject", "VertexRender"]
)
.testTarget(
    name: "VertexCompositionTests",
    dependencies: ["VertexComposition", "VertexProject", "VertexRender", "VertexMedia", "VertexCore"]
)
```

Add the product to the app and test dependencies in `project.yml`.

- [ ] **Step 2: Define compiler contracts in failing tests**

```swift
public enum CompositionFrameResolution: Equatable, Sendable {
    case frame(PortableImage)
    case transparent
}

public protocol CompositionFrameResolver: Sendable {
    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution
}

public struct CompositionRenderLimits: Codable, Equatable, Sendable {
    public var maximumDimension: Int = 8192
    public var maximumLayersPerComposition: Int = 256
    public var maximumNestedDepth: Int = 16
    public var maximumExpandedNodes: Int = 4096
}

public struct CompositionRenderRequest: Sendable {
    public var project: ProjectDocument
    public var compositionID: VertexID
    public var time: RationalTime
    public var output: RenderOutputSpecification
    public var limits: CompositionRenderLimits
}
```

Test exact bottom-to-top node order, Solo filtering, disabled/out-of-range exclusion, participating-only missing-media errors, negative source time transparency, adjustment placement, nested offset, child-duration transparency, frame deduplication, cycles, limits, cancellation, and deterministic cache context.

- [ ] **Step 3: Run compiler tests to verify RED**

```bash
swift test --filter VertexCompositionTests
```

Expected: compile failures for missing compiler implementation.

- [ ] **Step 4: Implement visibility selection**

```swift
struct CompositionVisibilityResolver {
    func participatingLayers(
        in composition: ProjectComposition,
        project: ProjectDocument,
        time: RationalTime
    ) throws -> [ProjectLayer]
}
```

Filter enabled and exact In/Out first. Determine Solo from active layers. Return top-to-bottom participating render-capable and adjustment layers while omitting model-only output. Missing media is checked only after this result is known.

- [ ] **Step 5: Implement deterministic recursive compilation**

```swift
public struct CompositionGraphCompiler: Sendable {
    public init()
    public func compile(
        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest
}
```

Start with a `RenderSource.solidColor` background node. Traverse authoritative layer IDs bottom-to-top. For media, map exact source time and resolve/cache a frame. For nested sources, recurse with a composition-ID stack. For adjustments, create one adjustment node over the current accumulator. Generate deterministic node IDs from composition ID, layer ID, role, and occurrence. Enforce all four limits before returning.

- [ ] **Step 6: Verify exact time and request-local cache**

Use a counting fake resolver. Compile two layers referencing the same media/time/size and assert one resolution. Assert negative media time returns transparency without invoking the resolver.

- [ ] **Step 7: Run portable composition and regression tests**

```bash
swift test --filter VertexCompositionTests
swift test
```

Expected: compiler tests and all existing portable tests pass.

- [ ] **Step 8: Commit compiler**

```bash
git add Package.swift project.yml Sources/VertexComposition Tests/VertexCompositionTests
git commit -m "feat: compile project compositions into render graphs"
```

---

### Task 7: Metal DAG Execution and Premultiplied Blend Kernels

**Files:**
- Create: `Sources/VertexRenderMetal/MetalGraphExecutor.swift`
- Create: `Sources/VertexRenderMetal/MetalTexturePool.swift`
- Create: `Sources/VertexRenderMetal/MetalRenderParameters.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderBackend.swift`
- Modify: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Test: `Tests/VertexRenderMetalTests/MetalRenderBackendTests.swift`
- Create: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`

**Interfaces:**
- Consumes: `RenderEvaluationPlan` and all Task 5 node kinds.
- Produces: exact RGBA8 graph execution with solid background, transformed layer operations, four blend modes, adjustment mix, texture reuse, and metrics.

- [ ] **Step 1: Add native pixel RED tests**

Use deterministic 1×1, 2×2, and 4×4 PNG fixtures. Decode output pixels and compare exact bytes or one-byte tolerance only where documented.

```swift
@Test("Multiply respects semitransparent premultiplied alpha")
func multiplyPremultipliedAlpha() async throws {
    let request = try RenderFixture.twoPixelRequest(
        backdrop: .rgba(128, 64, 32, 128),
        source: .rgba(64, 128, 255, 128),
        blend: .multiply
    )
    let result = try await MetalRenderBackend().render(
        request,
        cancellationToken: RenderCancellationToken()
    )
    #expect(try PixelFixture.rgba(result.image) == [/* fixed expected RGBA bytes */ 91, 77, 108, 192])
}

@Test("Transparent source RGB cannot contaminate normal output")
func transparentRGBDoesNotLeak() async throws {
    let request = try RenderFixture.transparentContaminationRequest()
    let result = try await MetalRenderBackend().render(request, cancellationToken: .init())
    #expect(try PixelFixture.rgba(result.image) == PixelFixture.expectedOpaqueBackdrop)
}
```

Before implementation, calculate and freeze all expected fixture bytes in the test file using the approved formulas, not the production shader.

- [ ] **Step 2: Run native tests to verify RED**

```bash
swift test --filter MetalCompositionPixelTests
```

Expected: graph node execution or shader function failures.

- [ ] **Step 3: Split Metal resources into explicit pipelines**

Load and compile:

```swift
solidPipeline       <- vertexSolidKernel
layerPipeline       <- vertexLayerKernel
compositePipeline   <- vertexCompositeKernel
adjustmentPipeline  <- vertexAdjustmentKernel
```

Keep bundled `default.metallib` loading with source fallback. Add Swift parameter structs whose field order and alignment exactly match Metal structs; assert expected `MemoryLayout.stride` in native tests.

- [ ] **Step 4: Implement shader semantics**

`vertexSolidKernel` fills output with premultiplied RGBA. `vertexLayerKernel` performs inverse anchor/position/scale/rotation sampling, exposure, saturation, inversion, opacity, and premultiplication. `vertexCompositeKernel` reads ordered backdrop/source textures and applies the approved alpha formula for Normal, Add, Multiply, and Screen. `vertexAdjustmentKernel` unpremultiplies safely, applies operations, premultiplies, and mixes original/adjusted values by adjustment opacity.

- [ ] **Step 5: Implement `MetalTexturePool` and `MetalGraphExecutor`**

```swift
final class MetalTexturePool: @unchecked Sendable {
    func acquire(width: Int, height: Int, usage: MTLTextureUsage) throws -> any MTLTexture
    func release(_ texture: any MTLTexture)
    var estimatedPeakBytes: Int { get }
}

struct MetalGraphExecutor {
    func execute(
        plan: RenderEvaluationPlan,
        output: RenderOutputSpecification,
        resources: MetalRenderResources,
        cancellationToken: RenderCancellationToken
    ) async throws -> MetalGraphExecutionResult
}
```

Evaluate topological nodes, store outputs by node ID, decrement consumer counts, and release textures after last use. Read back only the output node. Count decoded pixels, rendered layers, nodes, and peak texture bytes.

- [ ] **Step 6: Replace old single-source backend path**

`MetalRenderBackend.render` obtains `evaluationPlan()`, delegates to `MetalGraphExecutor`, encodes the final texture once, and returns metrics/cache key. Delete `sourceImage()` and `flattenedOperations()` after all tests compile.

- [ ] **Step 7: Run native and portable render tests**

```bash
swift test --filter VertexRenderMetalTests
swift test --filter VertexRenderTests
swift test --filter VertexCompositionTests
```

Expected: all blend, transform, adjustment, nested graph, cache, and cancellation tests pass on macOS.

- [ ] **Step 8: Compile the Metal source independently**

```bash
xcrun -sdk macosx metal \
  -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal \
  -o /tmp/VertexRenderKernels.air
```

Expected: exit 0.

- [ ] **Step 9: Commit Metal composition**

```bash
git add Sources/VertexRenderMetal Tests/VertexRenderMetalTests
git commit -m "feat: execute composition graphs with Metal"
```

---

### Task 8: App Media Resolver and Durable Composition Operations

**Files:**
- Create: `App/CompositionMediaFrameResolver.swift`
- Create: `App/ProjectWorkspaceCompositionCommands.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/MediaImportView.swift`
- Modify: `App/ProjectPackageFileDocument.swift`
- Test: `Tests/VertexProjectFoundationTests/ProjectPackageMigrationTests.swift`
- iOS compile verification through XcodeGen.

**Interfaces:**
- Consumes: package media store, AVFoundation frame provider, schema-aware package opening, and project operations.
- Produces: exact frame resolver and public durable workspace methods for every Phase 6 command.

- [ ] **Step 1: Add resolver contract tests with a fake URL provider**

Keep URL resolution behind an app-only protocol so logic can be tested without exposing URL in portable modules.

```swift
protocol CompositionMediaLocationResolving: Sendable {
    func resolvedURL(mediaID: VertexID) throws -> URL
}

actor CompositionMediaFrameResolver: CompositionFrameResolver {
    func resolve(
        mediaID: VertexID,
        exactSourceTime: RationalTime,
        targetSize: VertexSize
    ) async throws -> CompositionFrameResolution
}
```

Verify embedded media is preferred, bookmark fallback is used, stale bookmark/missing file returns `CompositionError.missingMedia`, and AVFoundation receives exact time plus target size.

- [ ] **Step 2: Refactor workspace command entry point**

Change private `performDurable` to one internal main-actor method:

```swift
func applyProjectOperation(
    _ operation: ProjectOperation,
    mergeKey: String? = nil
)
```

It must retain the exact sequence:

```text
pre-apply validation
→ durable journal append and synchronize
→ history perform
→ publish project
→ schedule autosave
```

Expose typed methods in `ProjectWorkspaceCompositionCommands.swift`, including create/duplicate/delete/select composition; insert/remove/duplicate/reorder/select layer; flags; timing; transform; blend; source; operations; camera; and light.

- [ ] **Step 3: Replace global Render Lab persistence**

Media import still registers media, then inserts a real media layer into the active composition. Remove new writes to global `ProjectRenderSettings`. Keep `legacyRenderSettings` read-only for migrated projects without a selected media layer.

- [ ] **Step 4: Make project opening schema-aware**

Use `ProjectPackageOpeningService`. For schema 1, generate a distinct internal migration destination, install the schema 2 result, reset history/journal as returned, and display a migration status. Future schema remains read-only/rejected and is never rewritten.

- [ ] **Step 5: Run portable tests and iOS compile**

```bash
swift test
xcodegen generate
xcodebuild \
  -project Vertex.xcodeproj \
  -scheme Vertex \
  -configuration Debug \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: all tests and app compilation pass.

- [ ] **Step 6: Commit app adapters and commands**

```bash
git add App Tests/VertexProjectFoundationTests
git commit -m "feat: connect durable composition commands and media frames"
```

---

### Task 9: Exact-Frame Composition Preview Controller

**Files:**
- Create: `App/CompositionPreviewController.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/RenderLabViewModel.swift`
- Modify: `App/RenderLabView.swift`
- Test through portable compiler/coordinator tests and iOS compilation.

**Interfaces:**
- Consumes: current `ProjectDocument`, `CompositionGraphCompiler`, `CompositionMediaFrameResolver`, `LatestRenderCoordinator`, and `MetalRenderBackend`.
- Produces: published exact frame, last successful image, current error, metrics, and PNG export payload.

- [ ] **Step 1: Implement exact frame navigation state**

```swift
@MainActor
final class CompositionPreviewController: ObservableObject {
    @Published private(set) var frameIndex: Int64 = 0
    @Published private(set) var result: RenderResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRendering = false

    func setFrameIndex(_ value: Int64, composition: ProjectComposition)
    func step(by frames: Int64, composition: ProjectComposition)
    func render(project: ProjectDocument, packageURL: URL?)
    func cancel()
    func exportPayload() -> RenderExportPayload?
}
```

Convert frame index to exact composition time using composition frame rate. Clamp to first/last valid frame. Never persist a floating-point second value.

- [ ] **Step 2: Compile and render latest requests**

On project revision, active composition, selected frame, output size, or media availability change:

```text
cancel previous compile/render
→ compile exact composition graph
→ LatestRenderCoordinator.renderLatest
→ publish only matching generation
```

Keep the previous successful `result` when a new request fails and publish the current error separately.

- [ ] **Step 3: Retire duplicate Render Lab path**

Move Phase 5 static controls into selected media-layer inspector state. Keep old `RenderLabView` only as a thin compatibility redirect during this task, then remove it from `MediaImportView` and `RootView` after Task 10 is green. PNG output uses `CompositionPreviewController.exportPayload()` from the same image displayed in preview.

- [ ] **Step 4: Verify app compilation and preview/output parity tests**

```bash
swift test --filter RenderSchedulingTests
swift test --filter CompositionGraphCompilerTests
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -sdk iphoneos \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 5: Commit preview controller**

```bash
git add App
git commit -m "feat: render exact composition frames in the app"
```

---

### Task 10: Functional Composition and Layer Workspace UI

**Files:**
- Create: `App/CompositionWorkspaceView.swift`
- Create: `App/CompositionHeaderView.swift`
- Create: `App/ExactFrameNavigatorView.swift`
- Create: `App/LayerListView.swift`
- Create: `App/LayerInspectorView.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `App/RootView.swift`
- Modify: `App/MediaImportView.swift`
- Delete after replacement: `App/RenderLabView.swift`
- Delete after replacement: `App/RenderLabViewModel.swift`

**Interfaces:**
- Consumes: workspace durable command methods and preview controller.
- Produces: actual composition selection/editing, exact-frame preview/navigation, layer order/flags, inspector controls, model-only disclosure, and existing persistence/recovery controls.

- [ ] **Step 1: Build `CompositionHeaderView`**

Provide active composition picker, create, duplicate, rename, delete, width, height, frame rate, duration, and background controls. Every commit invokes one typed project operation. Referenced deletion displays the structured error and leaves selection unchanged.

- [ ] **Step 2: Build `ExactFrameNavigatorView`**

Provide first, previous, next, last, direct frame field, and a simple scrub slider. Convert slider position to a clamped integer frame before calling the preview controller.

- [ ] **Step 3: Build `LayerListView`**

Display top Z-order first. Each row shows source type, name, enabled, lock, Solo, current-time activity, blend mode, missing media, and `Model only` for camera/light. Use `.onMove` or an explicit reorder control to emit exactly one `reorderLayer` operation with before/after indices.

Add menu entries:

```text
Media
Adjustment
Null
Guide
Camera
Light
Nested Composition
```

Disable invalid nested choices that would immediately form a cycle.

- [ ] **Step 4: Build `LayerInspectorView`**

Expose only supported fields: name, enabled, locked, Solo, Start/In/Out, position, anchor, independent scale, rotation, opacity, blend, exposure, saturation, invert, nested source/start, camera model data, and light model data. Locked layers disable all controls except the lock toggle. Model-only fields display `No Phase 6 output effect`.

Use merge keys such as:

```text
layer.<id>.transform.position
layer.<id>.transform.scaleX
layer.<id>.transform.rotation
layer.<id>.timing
layer.<id>.operations.exposure
```

Blend changes use no merge key.

- [ ] **Step 5: Compose `CompositionWorkspaceView`**

Show a transparent checkerboard behind the last successful image, render progress, metrics, exact error state, and PNG share/export using the same `RenderResult.image`. Keep Open, Save, package Export, Undo, Redo, autosave status, relink, embed, and recovery controls available.

- [ ] **Step 6: Replace old Root/Media flow**

Insert `CompositionWorkspaceView` after the project controls. Media import registers media and adds it to the active composition instead of opening Render Lab. Remove old Render Lab source files only after no app or test reference remains.

- [ ] **Step 7: Compile on iPhone and iPad generic targets**

```bash
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Debug \
  -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

Expected: Swift 6 actor isolation, SwiftUI generic types, file importer/exporter, and package dependencies compile with zero errors.

- [ ] **Step 8: Commit the workspace**

```bash
git add App
git commit -m "feat: add composition and layer workspace"
```

---

### Task 11: Phase 6 Integration, CI, Documentation, and IPA

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `Sources/VertexProject/ProjectModule.swift`
- Modify: `README.md`
- Create: `Documentation/LAYERS_COMPOSITIONS_ARCHITECTURE.md`
- Create: `Documentation/COMPOSITION_TEST_MATRIX.md`
- Create: `Documentation/PHASE_6_WORK_LOG.md`
- Create after verified build: `Documentation/PHASE_6_COMPLETION.md`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `Documentation/HANDOFF.md`

**Interfaces:**
- Consumes: every completed Phase 6 subsystem.
- Produces: verified product version, full regression evidence, Draft PR #6, and downloadable unsigned IPA.

- [ ] **Step 1: Open Draft PR #6 before the first implementation push if it does not exist**

Base: `agent/phase-5-project-persistence`

Title:

```text
Phase 6: layers, compositions, and 6.0.0 IPA
```

The body must state real multi-layer, adjustment, and nested rendering, model-only camera/light boundaries, schema 2 migration, excluded later features, and the requirement to remain Draft.

- [ ] **Step 2: Update version and build policy**

Set in `project.yml`:

```yaml
MARKETING_VERSION: 6.0.0
CURRENT_PROJECT_VERSION: 6
```

Update milestone number/title/deliverables and artifact policy. Do not claim continuous playback, timeline, animation, video export, or 3D.

- [ ] **Step 3: Update CI for all Phase 6 modules**

Rename jobs to include composition. Keep `swift test` on Linux. On macOS run:

```bash
swift test --filter VertexProjectFoundationTests
swift test --filter VertexRenderMetalTests
swift test --filter VertexCompositionTests
xcrun -sdk macosx metal -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal -o "$RUNNER_TEMP/VertexRenderKernels.air"
```

Build iOS Release without signing, verify display name, bundle ID, arm64, `6.0.0`, build `6`, `Assets.car`, and `Vertex_VertexRenderMetal.bundle/default.metallib`.

Package exactly:

```bash
zip -qry artifacts/After-Effects-6.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/After-Effects-6.0.0-unsigned.ipa \
  > artifacts/After-Effects-6.0.0-unsigned.ipa.sha256
```

Upload artifact name `After-Effects-6.0.0-unsigned-ipa`.

- [ ] **Step 4: Run the complete fresh local/CI-equivalent test set**

```bash
swift test
swift test --filter VertexProjectFoundationTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
```

Expected: zero failures. Record exact test counts from output rather than estimating.

- [ ] **Step 5: Run the fresh iOS Release build**

```bash
bash Tools/generate_app_assets.sh
xcodegen generate
xcodebuild \
  -project Vertex.xcodeproj \
  -scheme Vertex \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$PWD/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build
```

Expected: exit 0.

- [ ] **Step 6: Trigger and inspect the final GitHub Actions run**

Confirm every job and step succeeds on the final product/CI HEAD. Download the workflow artifact rather than using an earlier build.

- [ ] **Step 7: Inspect the downloaded artifact and IPA**

Verify:

```text
Payload/AfterEffects.app/AfterEffects
Mach-O 64-bit arm64
CFBundleDisplayName = After Effects
CFBundleIdentifier = com.woo642778.aftereffects
CFBundleShortVersionString = 6.0.0
CFBundleVersion = 6
MinimumOSVersion = 17.0
Assets.car exists
Vertex_VertexRenderMetal.bundle/default.metallib exists
```

Calculate the artifact ZIP SHA-256, IPA SHA-256, IPA byte size, and relevant resource byte sizes from the downloaded files. Compare the IPA checksum with the uploaded `.sha256` file.

- [ ] **Step 8: Write completion evidence without creating a checksum loop**

After the final product/CI HEAD and artifact are fixed, remove any temporary PR trigger if one was added. Ensure documentation-only paths remain ignored by the build trigger. Record exact commit SHA, workflow run ID, artifact ID, ZIP digest, IPA digest, test counts, binary identity, implemented behavior, excluded behavior, and unverified physical-device/manual scenarios.

- [ ] **Step 9: Update the handoff**

State Phase 6 branch/PR, schema 2, migration behavior, modules, final verification, artifact, current app behavior, fixed decisions, excluded features, and the Phase 7 Motion Engine design gate.

- [ ] **Step 10: Final requirements audit**

Re-read `docs/superpowers/specs/2026-08-05-phase-6-layers-compositions-design.md` line by line. Confirm each requirement maps to a passing test, visible working behavior, or explicit model-only/excluded statement. Search production and docs for false claims and stale `5.0.0`, build `5`, `SCHEMA 1`, placeholder composition, and Render Lab ownership.

Run:

```bash
git grep -nE '5\.0\.0|CURRENT_PROJECT_VERSION: 5|SCHEMA 1|ProjectCompositionPlaceholder|global Render Lab'
```

Expected: only historical documentation or schema 1 compatibility fixtures contain intentional matches.

- [ ] **Step 11: Commit final product documentation and keep PR Draft**

```bash
git add .github Package.swift project.yml Sources App Tests README.md Documentation docs
git commit -m "docs: complete Phase 6 verification and handoff"
```

Do not merge PR #6. Preserve the feature branch for review and later stacked integration.
