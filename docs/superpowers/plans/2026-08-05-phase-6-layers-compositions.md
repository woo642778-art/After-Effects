# Phase 6 Layers and Compositions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic schema 2 compositions and layers, real multi-source Metal compositing with Normal/Add/Multiply/Screen, adjustment layers, basic nested compositions, and a functional exact-frame workspace, then publish the verified unsigned `6.0.0 (6)` IPA.

**Architecture:** `VertexProject` owns portable schema 2 state, migration, commands, history, and validation. New module `VertexComposition` compiles one project composition at an exact `RationalTime` into a multi-source `VertexRender` DAG; `VertexRenderMetal` evaluates that DAG using premultiplied-alpha solid, layer, composite, and adjustment kernels. Only the app resolves package URLs, bookmarks, AVFoundation frames, SwiftUI state, and migration destinations.

**Tech Stack:** Swift 6.0, Swift Testing, Swift Package Manager, XcodeGen, SwiftUI, AVFoundation adapters, Foundation package persistence, Metal compute, GitHub Actions, iOS 17, macOS 14.

## Global Constraints

- Branch: `agent/phase-6-layers-compositions`; base: `agent/phase-5-project-persistence`.
- Draft PR #6 remains stacked on Phase 5 and is not merged automatically.
- Successful product version: `6.0.0 (6)`.
- Successful artifact: `After-Effects-6.0.0-unsigned.ipa`.
- Current project schema after migration: `2`.
- iOS deployment target remains `17.0`; package macOS floor remains `14`; Swift language version remains `6.0`.
- Preview and PNG output use the same `RenderResult.image` bytes.
- Portable project/compiler/render models contain no AVFoundation, Metal, UIKit, SwiftUI, URL bookmark object, file descriptor, or absolute sandbox path.
- All project time uses `RationalTime`; UI `Double` scrub values are immediately converted to integer frame indices.
- Limits: dimensions `1...8192`, layers per composition `256`, nesting depth `16`, expanded nodes `4096`.
- Schema 2 writes only `normal`, `add`, `multiply`, and `screen`.
- Null, guide, camera, and light persist and support commands but produce no Phase 6 pixels.
- Continuous playback, NLE editing, keyframes, parenting, motion blur, retiming, advanced pre-composition, camera/light rendering, video export, masks, tracking, AI, shapes, text, professional color/audio, particles, nodes, and 3D remain excluded.
- No new external dependency is added.
- Every production task follows RED → GREEN → full relevant regression → focused commit.

---

### Task 0: Execution Baseline and Draft PR

**Files:**
- No production files.
- PR: create Draft PR #6 if absent.

**Interfaces:**
- Consumes: Phase 5 branch state and approved Phase 6 design.
- Produces: a clean baseline, Draft PR, and CI location for every RED/GREEN cycle.

- [ ] **Step 1: Verify the branch base and documentation-only HEAD**

Run:

```bash
git status --short
git branch --show-current
git merge-base HEAD agent/phase-5-project-persistence
git log -3 --oneline
```

Expected: clean tree on `agent/phase-6-layers-compositions`; only the approved spec and plan differ from Phase 5.

- [ ] **Step 2: Run the Phase 5 baseline suite**

```bash
swift test
```

Expected: the existing 58 portable tests pass before Phase 6 production code begins.

- [ ] **Step 3: Create Draft PR #6**

Base: `agent/phase-5-project-persistence`

Title:

```text
Phase 6: layers, compositions, and 6.0.0 IPA
```

Body must state schema 2 migration, real multi-layer/adjustment/nested rendering, model-only camera/light boundaries, excluded later features, and that the PR remains Draft.

- [ ] **Step 4: Record baseline evidence in the PR**

Post the branch HEAD and baseline test count. Do not claim Phase 6 functionality yet.

---

### Task 1: Schema 2 Composition and Layer Values

**Files:**
- Create: `Sources/VertexProject/ProjectRGBAColor.swift`
- Create: `Sources/VertexProject/ProjectComposition.swift`
- Create: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Modify: `Sources/VertexProject/ProjectError.swift`
- Create: `Tests/VertexProjectTests/ProjectCompositionSchemaTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectCodecTests.swift`

**Interfaces:**
- Produces: `ProjectRGBAColor`, `ProjectComposition`, `ProjectLayer`, `LayerSource`, `LayerTiming`, `LayerTransform`, `LayerOperation`, `LayerBlendMode`, `AdjustmentScope`, `CameraLayerSettings`, `LightLayerSettings`, and schema 2 `ProjectDocument` validation/lookups.
- Consumes: `VertexID`, `RationalTime`, `ColorDescriptor`, `MediaReference`.

- [ ] **Step 1: Write failing schema tests**

```swift
@Test("Canonical schema 2 preserves composition Z-order")
func canonicalSchemaPreservesZOrder() throws {
    let fixture = try ProjectDocument.twoLayerFixture()
    let codec = DeterministicProjectCodec()
    let decoded = try codec.decode(codec.encode(fixture.document))
    #expect(decoded.schemaVersion == 2)
    #expect(decoded.layerRegistry.map(\.id) == [fixture.bottom.id, fixture.top.id])
    #expect(decoded.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Direct and indirect nested cycles are rejected")
func nestedCyclesFailValidation() throws {
    #expect(throws: ProjectError.self) { try ProjectDocument.directCycleFixture().validated() }
    #expect(throws: ProjectError.self) { try ProjectDocument.indirectCycleFixture().validated() }
}
```

Add explicit tests for duplicate IDs, ownership mismatch, missing source identity, invalid In/Out, non-finite transform, model-only blend/operation restrictions, and unsupported blend decoding.

- [ ] **Step 2: Run the RED tests**

```bash
swift test --filter ProjectCompositionSchemaTests
```

Expected: compile failure because schema 2 types do not exist.

- [ ] **Step 3: Implement exact value types**

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
}

public enum LayerBlendMode: String, Codable, CaseIterable, Sendable {
    case normal, add, multiply, screen
}

public struct LayerTiming: Codable, Equatable, Sendable {
    public var startTime: RationalTime
    public var inPoint: RationalTime
    public var outPoint: RationalTime
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
    public static let identity = LayerTransform(
        positionX: 0.5, positionY: 0.5,
        anchorX: 0.5, anchorY: 0.5,
        scaleX: 1, scaleY: 1,
        rotationDegrees: 0, opacity: 1
    )
}

public enum LayerOperation: Codable, Equatable, Sendable {
    case exposure(stops: Double)
    case saturation(value: Double)
    case invert(enabled: Bool)
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
}
```

Camera fields are exactly projection, focal length, near/far clip, position XYZ, and point-of-interest XYZ. Light fields are exactly kind, RGBA color, intensity, position XYZ, direction XYZ, cone angle, and cone feather. Enforce the approved numeric ranges.

- [ ] **Step 4: Upgrade `ProjectDocument`**

Set:

```swift
public static let currentSchemaVersion = 2
public static let currentAppVersion = "6.0.0"
```

Root fields:

```swift
public var compositionRegistry: [ProjectComposition]
public var layerRegistry: [ProjectLayer]
public var activeCompositionID: VertexID?
public var selectedLayerID: VertexID?
public var selectedMediaID: VertexID?
public var legacyRenderSettings: ProjectRenderSettings?
```

Helpers:

```swift
public func composition(id: VertexID) -> ProjectComposition?
public func layer(id: VertexID) -> ProjectLayer?
public func layers(in compositionID: VertexID) -> [ProjectLayer]
public func nestedCompositionCycle() -> [VertexID]?
```

`normalized()` sorts registries and applied command IDs by stable ID but never sorts `ProjectComposition.layerIDs`. `validated()` checks all identities, ownership, timing, source references, model-only restrictions, and nested cycles.

- [ ] **Step 5: Run schema and codec tests**

```bash
swift test --filter ProjectCompositionSchemaTests
swift test --filter ProjectCodecTests
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add schema 2 composition and layer values"
```

---

### Task 2: Deterministic Schema 1 to 2 Migration

**Files:**
- Modify: `Sources/VertexCore/VertexID.swift`
- Create: `Sources/VertexProject/DeterministicVertexID.swift`
- Create: `Sources/VertexProject/Schema1Compatibility.swift`
- Create: `Sources/VertexProject/Schema1To2Migrator.swift`
- Modify: `Sources/VertexProject/ProjectMigration.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Create: `Tests/VertexProjectTests/ProjectSchemaMigrationTests.swift`
- Create: `Tests/VertexProjectTests/Fixtures/schema1-selected-media.json`
- Create: `Tests/VertexProjectTests/Fixtures/schema1-no-composition.json`

**Interfaces:**
- Produces: stable digest-derived IDs, frozen schema 1 DTOs/replay, and registered `Schema1To2Migrator`.
- Consumes: Task 1 schema 2 values.

- [ ] **Step 1: Write failing migration tests**

```swift
@Test("Schema 1 selected media migrates to one deterministic media layer")
func selectedMediaMigratesDeterministically() throws {
    let input = try Fixture.data("schema1-selected-media.json")
    let first = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let second = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    #expect(first.data == second.data)
    let project = try DeterministicProjectCodec().decode(first.data)
    #expect(project.layerRegistry.count == 1)
    #expect(project.layerRegistry[0].transform.opacity == 0.75)
    #expect(project.layerRegistry[0].operations.contains(.exposure(stops: 1.25)))
    #expect(project.legacyRenderSettings == nil)
}

@Test("Schema 1 without selected media creates no fake layer")
func noSelectionPreservesLegacyValues() throws {
    let input = try Fixture.data("schema1-no-composition.json")
    let result = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let project = try DeterministicProjectCodec().decode(result.data)
    #expect(project.compositionRegistry.count == 1)
    #expect(project.layerRegistry.isEmpty)
    #expect(project.legacyRenderSettings != nil)
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --filter ProjectSchemaMigrationTests
```

Expected: failure because no 1→2 migrator exists.

- [ ] **Step 3: Implement stable UUID derivation**

Add a checked initializer unconditionally:

```swift
public init(uuidBytes: [UInt8]) throws
```

It requires exactly 16 bytes and formats the canonical lowercase UUID string.

Expose digest bytes:

```swift
public static func digest(_ data: Data) -> [UInt8]
```

Derive IDs:

```swift
public enum DeterministicVertexID {
    public static func derive(domain: String, components: [String]) throws -> VertexID {
        let payload = ([domain] + components).joined(separator: "\u{1f}")
        var bytes = Array(StableProjectSHA256.digest(Data(payload.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return try VertexID(uuidBytes: bytes)
    }
}
```

Freeze exact domain-vector expected IDs in tests.

- [ ] **Step 4: Implement private schema 1 compatibility types**

`Schema1Compatibility.swift` contains the exact Phase 5 wire shapes for project, render settings, placeholder, operation, command, history, manifest, and journal. Implement `Schema1CommandEngine` and:

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

- [ ] **Step 5: Implement and register `Schema1To2Migrator`**

```swift
public struct Schema1To2Migrator: ProjectMigrator {
    public let sourceVersion = 1
    public let destinationVersion = 2
    public func migrate(_ data: Data) throws -> ProjectMigrationStepResult
}

public static let current = ProjectMigrationRegistry(
    migrators: [Schema1To2Migrator()]
)
```

Reuse placeholder IDs; otherwise derive `Main Composition`. Use old output dimensions, project frame rate/color, exact ten-second duration, transparent background, and full In/Out. Move selected media plus old static Render Lab values into one media layer, or preserve them in `legacyRenderSettings` without creating a layer.

- [ ] **Step 6: Run migration and project tests**

```bash
swift test --filter ProjectSchemaMigrationTests
swift test --filter VertexProjectTests
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/VertexCore Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: migrate project schema deterministically"
```

---

### Task 3: Composition and Layer Commands

**Files:**
- Create: `Sources/VertexProject/ProjectCommandPayloads.swift`
- Create: `Sources/VertexProject/ProjectDuplicationFactory.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectHistory.swift`
- Create: `Tests/VertexProjectTests/ProjectCompositionCommandTests.swift`
- Create: `Tests/VertexProjectTests/ProjectLayerCommandTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectCommandTests.swift`

**Interfaces:**
- Produces: exact reversible composition/layer operations and deterministic duplication payloads.
- Consumes: validated schema 2 values.

- [ ] **Step 1: Write failing command tests**

```swift
@Test("Reorder undo restores exact Z-order")
func reorderUndoRestoresExactIndex() throws {
    let fixture = try ProjectDocument.twoLayerFixture()
    let controller = try ProjectHistoryController(project: fixture.document)
    try controller.perform(.reorderLayer(
        compositionID: fixture.composition.id,
        layerID: fixture.bottom.id,
        beforeIndex: 1,
        afterIndex: 0
    ))
    _ = try controller.undo()
    #expect(controller.project.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Referenced child composition cannot be removed")
func referencedChildRemovalFails() throws {
    let fixture = try ProjectDocument.nestedFixture()
    let before = fixture.document
    #expect(throws: ProjectError.self) {
        try ProjectCommandEngine().apply(
            ProjectCommandRecord(project: before, operation: .removeComposition(
                fixture.child, ownedLayers: [], previousActiveID: fixture.parent.id, previousSelection: nil
            )),
            to: before
        )
    }
}
```

Add cases for every approved composition and layer command, exact preconditions, cycle rejection, duplicate identity, and locked-layer edit refusal except unlock.

- [ ] **Step 2: Run RED**

```bash
swift test --filter ProjectCompositionCommandTests
swift test --filter ProjectLayerCommandTests
```

Expected: missing operation cases.

- [ ] **Step 3: Implement command payloads and operations**

Retain Phase 5 media/project operations. Add:

```swift
case createComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int)
case removeComposition(ProjectComposition, ownedLayers: [ProjectLayer], registryIndex: Int, previousActiveID: VertexID?, previousSelection: VertexID?)
case duplicateComposition(sourceID: VertexID, composition: ProjectComposition, layers: [ProjectLayer], registryIndex: Int)
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
```

Camera/light edits use `setLayerSource` with exact before/after records. `ProjectDuplicationFactory` derives all new IDs before a command is created and remaps only nested references inside the duplicated payload.

- [ ] **Step 4: Extend history coalescing**

Coalesce chained transform, timing, and operation changes only when project, layer, merge key, time window, and previous-after/current-before match. Blend changes have no merge key. Failed undo/redo preparation must preserve project bytes, Z-order, selection, and stack counts.

- [ ] **Step 5: Run all project command/history/journal tests**

```bash
swift test --filter VertexProjectTests
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add composition and layer command history"
```

---

### Task 4: Non-Destructive Package Migration and Recovery

**Files:**
- Create: `Sources/VertexProjectFoundation/Schema1PackageReader.swift`
- Create: `Sources/VertexProjectFoundation/ProjectPackageMigrator.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectRecovery.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`
- Create: `Tests/VertexProjectFoundationTests/ProjectPackageMigrationTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectPackageStoreTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectRecoveryTests.swift`

**Interfaces:**
- Produces: schema-aware package opening and a separate schema 2 working package.
- Consumes: Task 2 schema 1 replay and migrator.

- [ ] **Step 1: Write failing package migration tests**

```swift
@Test("Schema 1 package migration preserves source and resets incompatible history")
func packageMigrationIsNonDestructive() throws {
    let fixture = try Schema1PackageFixture.make()
    let before = try fixture.snapshotBytes()
    let destination = fixture.root.appendingPathComponent("Migrated.aeproject")
    let result = try ProjectPackageMigrator().migrate(
        schema1PackageURL: fixture.packageURL,
        destinationURL: destination
    )
    #expect(result.loadResult.document.schemaVersion == 2)
    #expect(result.loadResult.document.revision == fixture.recoveredRevision)
    #expect(result.loadResult.history == ProjectHistorySnapshot())
    #expect(result.loadResult.manifest.committedJournalSequence == 0)
    #expect(try fixture.snapshotBytes() == before)
}
```

Add injected destination-write failure and future-schema no-rewrite tests.

- [ ] **Step 2: Run RED**

```bash
swift test --filter ProjectPackageMigrationTests
```

Expected: missing package migrator.

- [ ] **Step 3: Implement schema 1 package reading**

Verify schema 1 project/manifest checksum and identity, decode history/journal with compatibility DTOs, replay complete records newer than the committed sequence, and return one recovered logical schema 1 snapshot. Never write source files.

- [ ] **Step 4: Implement migration/opening services**

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

Sequence: verify/replay schema 1 → migrate canonical bytes → decode/validate schema 2 → create destination with empty history/journal sequence 0 → readback/checksum verify. Delete partial destination on failure; preserve source.

- [ ] **Step 5: Add schema 2 save/autosave/recovery regressions**

Assert composition/layer ownership and exact Z-order survive save/reopen, autosave rotation, backup recovery, and recovered-package creation. Mismatched backup history opens empty.

- [ ] **Step 6: Run Foundation tests**

```bash
swift test --filter VertexProjectFoundationTests
```

Expected: all pass.

- [ ] **Step 7: Commit**

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
- Create: `Tests/VertexRenderTests/RenderMultiSourceTests.swift`
- Modify: `Tests/VertexRenderTests/RenderGraphTests.swift`
- Modify: `Tests/VertexRenderTests/RenderSchedulingTests.swift`

**Interfaces:**
- Produces: ordered multi-source node-local evaluation plan and deterministic render cache context.
- Consumes: `PortableImage`, `RationalTime`, `VertexID`, `ColorDescriptor`.

- [ ] **Step 1: Write failing DAG tests**

```swift
@Test("Composite dependency order is backdrop then source")
func compositeOrderIsSemantic() throws {
    let graph = try RenderGraph.twoSourceFixture(blendMode: .multiply)
    let node = try #require(try graph.evaluationPlan().orderedNodes.first {
        if case .composite = $0.kind { return true }
        return false
    })
    #expect(node.dependencies == [RenderGraph.fixtureBackdropID, RenderGraph.fixtureSourceID])
}

@Test("Disconnected graph nodes fail validation")
func disconnectedNodesFail() {
    #expect(throws: RenderError.self) { try RenderGraph.disconnectedFixture().evaluationPlan() }
}
```

Add tests for multiple sources, local operations, arity, missing dependencies, cycles, and cache changes by composition/revision/time/output.

- [ ] **Step 2: Run RED**

```bash
swift test --filter RenderMultiSourceTests
```

Expected: missing multi-source node types.

- [ ] **Step 3: Implement render values**

```swift
public struct RenderRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
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

public enum RenderNodeKind: Codable, Equatable, Sendable {
    case source(RenderSource)
    case operations([RenderOperation])
    case composite(RenderBlendMode)
    case adjustment([RenderOperation], mix: Double)
    case output
}

public struct RenderCacheContext: Codable, Equatable, Sendable {
    public var compositionID: VertexID
    public var projectRevision: UInt64
    public var compilerVersion: Int
}
```

Add `transform2D(RenderTransform2D)` to `RenderOperation`. `solidColor` is the portable deterministic composition background source.

- [ ] **Step 4: Implement `RenderEvaluationPlan`**

```swift
public struct RenderEvaluationPlan: Equatable, Sendable {
    public var orderedNodes: [RenderNode]
    public var outputNodeID: VertexID
    public var consumerCounts: [VertexID: Int]
}

public func evaluationPlan() throws -> RenderEvaluationPlan
```

Require one output, allow many sources, preserve dependency order, and reject duplicate/missing/disconnected/cyclic nodes. Node arity: source 0, operations 1, adjustment 1, composite 2 ordered `[backdrop, source]`, output 1.

Extend `RenderMetrics` with `expandedNodeCount`, `renderedLayerCount`, and `estimatedPeakTextureBytes`, all defaulting to `0` in the initializer so existing backends/tests remain source-compatible until Task 7. Add optional `RenderCacheContext` to `RenderRequest` and include it in cache bytes.

- [ ] **Step 5: Run render tests**

```bash
swift test --filter VertexRenderTests
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexRender Tests/VertexRenderTests
git commit -m "feat: extend render graph for multi-source composition"
```

---

### Task 6: Platform-Neutral `VertexComposition` Compiler

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
- Produces: `CompositionGraphCompiler.compile` and platform-free exact frame resolution.
- Consumes: Tasks 1 and 5.

- [ ] **Step 1: Wire product and test target**

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

Create `CompositionModule.swift` with a public module identifier so SwiftPM has a valid source before RED tests compile. Add product/test dependencies to `project.yml`.

- [ ] **Step 2: Write failing compiler tests**

Final contracts:

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
    public var maximumDimension: Int
    public var maximumLayersPerComposition: Int
    public var maximumNestedDepth: Int
    public var maximumExpandedNodes: Int
    public static let standard = CompositionRenderLimits(
        maximumDimension: 8192,
        maximumLayersPerComposition: 256,
        maximumNestedDepth: 16,
        maximumExpandedNodes: 4096
    )
}

public struct CompositionRenderRequest: Sendable {
    public var project: ProjectDocument
    public var compositionID: VertexID
    public var time: RationalTime
    public var output: RenderOutputSpecification
    public var limits: CompositionRenderLimits
}
```

Test bottom-to-top order, enabled/timing/Solo, participating-only missing media, negative source time transparency, adjustment placement, nested offset and child bounds, frame deduplication, cycles, limits, cancellation, and cache context.

- [ ] **Step 3: Run RED**

```bash
swift test --filter VertexCompositionTests
```

Expected: missing compiler types.

- [ ] **Step 4: Implement visibility and recursive compilation**

```swift
struct CompositionVisibilityResolver {
    func participatingLayers(
        in composition: ProjectComposition,
        project: ProjectDocument,
        time: RationalTime
    ) throws -> [ProjectLayer]
}

public struct CompositionGraphCompiler: Sendable {
    public init() {}
    public func compile(
        _ request: CompositionRenderRequest,
        resolver: any CompositionFrameResolver,
        cancellationToken: RenderCancellationToken
    ) async throws -> RenderRequest
}
```

Start with `RenderSource.solidColor`, traverse authoritative IDs bottom-to-top, cache media by `mediaID + exact time + target size`, recurse nested compositions with an ID stack, insert adjustment nodes over the accumulator, generate deterministic node IDs, and enforce all limits before returning. Negative media time and nested time outside child duration produce transparency without I/O.

- [ ] **Step 5: Run compiler and full portable tests**

```bash
swift test --filter VertexCompositionTests
swift test
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Package.swift project.yml Sources/VertexComposition Tests/VertexCompositionTests
git commit -m "feat: compile project compositions into render graphs"
```

---

### Task 7: Metal DAG Execution and Blend Kernels

**Files:**
- Create: `Sources/VertexRenderMetal/MetalRenderParameters.swift`
- Create: `Sources/VertexRenderMetal/MetalTexturePool.swift`
- Create: `Sources/VertexRenderMetal/MetalGraphExecutor.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderBackend.swift`
- Modify: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Create: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`
- Modify: `Tests/VertexRenderMetalTests/MetalRenderBackendTests.swift`

**Interfaces:**
- Produces: premultiplied RGBA8 solid/layer/composite/adjustment execution and texture last-use reuse.
- Consumes: `RenderEvaluationPlan`.

- [ ] **Step 1: Write failing native pixel tests**

`PixelFixture.premultipliedRGBA(_:)` decodes PNG into the same premultiplied RGBA8 representation used by `MetalImageCodec`.

```swift
@Test("Multiply uses approved semitransparent alpha formula")
func multiplyPremultipliedAlpha() async throws {
    let request = try RenderFixture.twoSourceRequest(
        backdrop: .rgba(128, 64, 32, 128),
        source: .rgba(64, 128, 255, 128),
        blend: .multiply
    )
    let result = try await MetalRenderBackend().render(
        request,
        cancellationToken: RenderCancellationToken()
    )
    #expect(try PixelFixture.premultipliedRGBA(result.image) == [56, 56, 80, 192])
}

@Test("Transparent RGB cannot contaminate output")
func transparentRGBDoesNotLeak() async throws {
    let result = try await MetalRenderBackend().render(
        try RenderFixture.transparentContaminationRequest(),
        cancellationToken: RenderCancellationToken()
    )
    #expect(try PixelFixture.premultipliedRGBA(result.image) == [40, 80, 120, 255])
}
```

Freeze exact tests for Normal, Add, Multiply, Screen, position, anchor, independent scale, rotation, opacity, exposure, saturation, invert, adjustment mix, two sources, and nested graph output.

- [ ] **Step 2: Run RED on macOS**

```bash
swift test --filter MetalCompositionPixelTests
```

Expected: missing shader pipelines/DAG executor.

- [ ] **Step 3: Implement four pipeline resources**

Load:

```text
vertexSolidKernel
vertexLayerKernel
vertexCompositeKernel
vertexAdjustmentKernel
```

Define Swift and Metal parameter structs with identical field order/alignment and assert their exact `MemoryLayout.stride` in native tests.

- [ ] **Step 4: Implement shader semantics**

Solid fills premultiplied RGBA. Layer performs inverse anchor/position/scale/rotation sampling, exposure, saturation, inversion, opacity, and premultiplication. Composite uses ordered backdrop/source textures and the approved blend/alpha equations. Adjustment safely unpremultiplies, applies operations, premultiplies, and mixes original/adjusted by opacity.

- [ ] **Step 5: Implement texture pool and executor**

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

Evaluate node-local operations, decrement consumer counts, release after last use, read back only output, and report pixels/nodes/layers/peak bytes.

- [ ] **Step 6: Replace the old flattened backend**

`MetalRenderBackend.render` uses `evaluationPlan()` and `MetalGraphExecutor`. Delete `sourceImage()` and `flattenedOperations()` after compilation succeeds.

- [ ] **Step 7: Run native and portable render tests**

```bash
swift test --filter VertexRenderMetalTests
swift test --filter VertexRenderTests
swift test --filter VertexCompositionTests
xcrun -sdk macosx metal -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal -o /tmp/VertexRenderKernels.air
```

Expected: all pass; Metal compile exits 0.

- [ ] **Step 8: Commit**

```bash
git add Sources/VertexRenderMetal Tests/VertexRenderMetalTests
git commit -m "feat: execute composition graphs with Metal"
```

---

### Task 8: App Media Resolver and Exact Preview Controller

**Files:**
- Create: `App/CompositionMediaFrameResolver.swift`
- Create: `App/CompositionPreviewController.swift`
- Create: `App/ProjectWorkspaceCompositionCommands.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/MediaImportView.swift`
- Modify: `App/ProjectPackageFileDocument.swift`

**Interfaces:**
- Produces: app-only media URL/frame adapter, durable typed command methods, exact frame navigation, latest render, last-success retention, and PNG payload.
- Consumes: Tasks 3, 4, 6, and 7.

- [ ] **Step 1: Implement app-only media resolution**

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

Resolution order: verified embedded file → valid bookmark → structured missing-media error. Request AVFoundation with exact time and target size.

- [ ] **Step 2: Expose one durable command entry point**

```swift
@MainActor
func applyProjectOperation(
    _ operation: ProjectOperation,
    mergeKey: String? = nil
)
```

Order remains validate → append/synchronize journal → history perform → publish → autosave. Add typed composition/layer methods in the extension file.

- [ ] **Step 3: Make opening schema-aware**

Use `ProjectPackageOpeningService`. Schema 1 opens a distinct migrated internal package; schema 2 opens directly; future schema is not rewritten. Display migration status.

- [ ] **Step 4: Replace new global Render Lab writes**

Media import registers media and inserts a real media layer into the active composition. `legacyRenderSettings` is read-only migration preservation.

- [ ] **Step 5: Implement exact preview controller**

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

Convert frame index to exact time. Cancel prior compile/render, compile with `CompositionGraphCompiler`, use `LatestRenderCoordinator`, publish matching generation only, and retain previous successful result on failure.

- [ ] **Step 6: Run full portable suite and iOS Debug build**

```bash
swift test
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Debug \
  -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add App
git commit -m "feat: connect composition media and exact preview"
```

---

### Task 9: Functional Composition Workspace UI

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
- Produces: actual composition/layer editing and exact preview without a decorative timeline.
- Consumes: Task 8 workspace/controller.

- [ ] **Step 1: Build composition header**

Active picker; create, duplicate, rename, delete; width/height, frame rate, duration, and background. Each accepted edit sends one durable command. Referenced deletion displays an error and leaves state unchanged.

- [ ] **Step 2: Build exact frame navigator**

First, previous, next, last, direct integer frame entry, and scrub slider converted immediately to a clamped integer frame.

- [ ] **Step 3: Build layer list**

Top row is top Z-order. Show source type, name, enabled, lock, Solo, current activity, blend, missing media, and `Model only` for camera/light. One move emits one reorder command. Add Media, Adjustment, Null, Guide, Camera, Light, and valid Nested Composition.

- [ ] **Step 4: Build inspector**

Expose name, flags, Start/In/Out, position, anchor, scale X/Y, rotation, opacity, blend, exposure, saturation, invert, nested source/start, and camera/light model fields. Locked layers expose only unlock. Camera/light display `No Phase 6 output effect`.

Use merge keys:

```text
layer.<id>.transform.position
layer.<id>.transform.scaleX
layer.<id>.transform.scaleY
layer.<id>.transform.rotation
layer.<id>.timing
layer.<id>.operations.exposure
layer.<id>.operations.saturation
```

Blend changes use no merge key.

- [ ] **Step 5: Build workspace composition**

Show checkerboard, last successful image, progress, current error, metrics, and PNG share/export from the same `RenderResult.image`. Preserve Open, Save, package Export, Undo, Redo, autosave, relink, embed, and recovery controls.

- [ ] **Step 6: Replace old Render Lab flow**

Root displays the composition workspace. Media import adds a layer. Remove old Render Lab files only after `git grep RenderLab` shows no production/test reference except historical documentation.

- [ ] **Step 7: Compile**

```bash
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Debug \
  -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add App
git commit -m "feat: add composition and layer workspace"
```

---

### Task 10: Integration, CI, Documentation, and IPA

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
- Produces: verified `6.0.0 (6)` source, CI, evidence, and unsigned IPA.
- Consumes: all prior tasks.

- [ ] **Step 1: Update product version and truthful milestone**

```yaml
MARKETING_VERSION: 6.0.0
CURRENT_PROJECT_VERSION: 6
```

Update Phase 6 milestone deliverables without claiming excluded features.

- [ ] **Step 2: Update CI**

Linux:

```bash
swift test
```

macOS:

```bash
swift test --filter VertexProjectFoundationTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
xcrun -sdk macosx metal -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal -o "$RUNNER_TEMP/VertexRenderKernels.air"
```

Build iOS Release unsigned and verify display name, bundle ID, arm64, version `6.0.0`, build `6`, `Assets.car`, and `default.metallib`.

Package exactly:

```bash
zip -qry artifacts/After-Effects-6.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/After-Effects-6.0.0-unsigned.ipa \
  > artifacts/After-Effects-6.0.0-unsigned.ipa.sha256
```

Artifact name: `After-Effects-6.0.0-unsigned-ipa`.

- [ ] **Step 3: Run fresh complete verification**

```bash
swift test
swift test --filter VertexProjectFoundationTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
bash Tools/generate_app_assets.sh
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Release \
  -sdk iphoneos -destination "generic/platform=iOS" \
  -derivedDataPath "$PWD/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" clean build
```

Expected: zero failures and build exit 0. Record exact test counts from output.

- [ ] **Step 4: Verify final GitHub Actions run**

Use the final product/CI HEAD. Confirm every job/step succeeds. Download that run's artifact, not an earlier one.

- [ ] **Step 5: Inspect downloaded IPA**

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

Calculate artifact ZIP SHA-256, IPA SHA-256, IPA byte size, and resource sizes. Compare against the uploaded `.sha256` file.

- [ ] **Step 6: Write final evidence**

Record exact product/CI commit, workflow run ID, artifact ID, ZIP digest, IPA digest, test counts, binary identity, implemented behavior, excluded behavior, and unverified physical-device/manual scenarios. Documentation-only commits must remain ignored by the build trigger to avoid a checksum loop.

- [ ] **Step 7: Audit stale claims and requirements**

```bash
git grep -nE '5\.0\.0|CURRENT_PROJECT_VERSION: 5|SCHEMA 1|ProjectCompositionPlaceholder|global Render Lab'
```

Expected: matches only in historical documentation, frozen schema 1 compatibility, or migration fixtures. Re-read the approved design and map every requirement to a test, real UI behavior, or explicit exclusion/model-only statement.

- [ ] **Step 8: Update handoff and PR comment**

Document branch/PR, schema 2 migration, modules, final evidence, current behavior, exclusions, and the Phase 7 Motion Engine design gate. Keep PR #6 Draft and unmerged.

- [ ] **Step 9: Commit final evidence**

```bash
git add .github Package.swift project.yml Sources App Tests README.md Documentation docs
git commit -m "docs: complete Phase 6 verification and handoff"
```
