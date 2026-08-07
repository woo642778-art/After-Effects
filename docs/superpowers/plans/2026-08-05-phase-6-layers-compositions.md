# Phase 6 Layers and Compositions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic schema 2 compositions and layers, real multi-source Metal compositing with Normal/Add/Multiply/Screen, adjustment layers, basic nested compositions, and a functional exact-frame workspace, then publish the verified unsigned `6.0.0 (6)` IPA.

**Architecture:** `VertexProject` owns portable schema 2 state, migration, commands, history, and validation. New module `VertexComposition` compiles one project composition at exact `RationalTime` into a multi-source `VertexRender` DAG; `VertexRenderMetal` evaluates that DAG with premultiplied-alpha solid, layer, composite, and adjustment kernels. Only app/Foundation adapters resolve package URLs, bookmarks, AVFoundation frames, SwiftUI state, and migration destinations.

**Tech Stack:** Swift 6.0, Swift Testing, Swift Package Manager, XcodeGen, SwiftUI, AVFoundation adapters, Foundation package persistence, Metal compute, GitHub Actions, iOS 17, macOS 14.

## Global Constraints

- Branch `agent/phase-6-layers-compositions`; base `agent/phase-5-project-persistence`.
- Draft PR #6 remains stacked on Phase 5 and unmerged.
- Product `6.0.0 (6)`; artifact `After-Effects-6.0.0-unsigned.ipa`; schema `2`.
- iOS `17.0`, macOS package floor `14`, Swift `6.0`.
- Preview and PNG output consume identical `RenderResult.image` bytes.
- Portable models contain no AVFoundation, Metal, UIKit, SwiftUI, security-scoped URL object, file descriptor, or absolute sandbox path.
- All project time uses `RationalTime`; scrub UI converts immediately to integer frame indices.
- Limits: dimensions `1...8192`, layers `256`, nested depth `16`, expanded nodes `4096`.
- Schema 2 writes only `normal`, `add`, `multiply`, `screen`.
- Null, guide, camera, and light are model-only and produce no Phase 6 pixels.
- Playback, NLE edits, keyframes, parenting, motion blur, retiming, advanced pre-composition, camera/light rendering, video export, masks, tracking, AI, shapes, text, professional color/audio, particles, nodes, and 3D remain excluded.
- No new external dependency.
- Schema, commands, migration, compiler, and Metal follow RED → GREEN → relevant regressions → focused commit.

---

### Task 0: Baseline and Draft PR

**Files:** None.

**Interfaces:** Establishes clean branch, baseline tests, and CI/PR location.

- [ ] **Step 1: Verify branch state**

```bash
git status --short
git branch --show-current
git merge-base HEAD agent/phase-5-project-persistence
git log -3 --oneline
```

Expected: clean `agent/phase-6-layers-compositions`; only approved Phase 6 spec/plan commits are ahead of Phase 5.

- [ ] **Step 2: Run Phase 5 baseline**

```bash
swift test
```

Expected: existing 58 portable tests pass.

- [ ] **Step 3: Create Draft PR #6**

Base `agent/phase-5-project-persistence`; title `Phase 6: layers, compositions, and 6.0.0 IPA`. Body states schema 2 migration, real media/adjustment/nested rendering, model-only camera/light, exclusions, and Draft status.

- [ ] **Step 4: Post baseline HEAD and test count to PR**

Do not claim Phase 6 functionality.

---

### Task 1: Schema 2 Values and Validation

**Files:**
- Create: `Sources/VertexProject/ProjectRGBAColor.swift`
- Create: `Sources/VertexProject/ProjectComposition.swift`
- Create: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift`
- Modify: `Sources/VertexProject/ProjectError.swift`
- Create: `Tests/VertexProjectTests/ProjectCompositionSchemaTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectCodecTests.swift`

**Interfaces:** Produces `ProjectRGBAColor`, `ProjectComposition`, `ProjectLayer`, `LayerSource`, `LayerTiming`, `LayerTransform`, `LayerOperation`, `LayerBlendMode`, `AdjustmentScope`, `CameraLayerSettings`, `LightLayerSettings`, and schema 2 `ProjectDocument`.

- [ ] **Step 1: Write failing schema tests**

```swift
@Test("Canonical schema 2 preserves authoritative Z-order")
func canonicalSchemaPreservesZOrder() throws {
    let fixture = try ProjectDocument.twoLayerFixture()
    let codec = DeterministicProjectCodec()
    let decoded = try codec.decode(codec.encode(fixture.document))
    #expect(decoded.schemaVersion == 2)
    #expect(decoded.layerRegistry.map(\.id) == [fixture.bottom.id, fixture.top.id])
    #expect(decoded.composition(id: fixture.composition.id)?.layerIDs == [fixture.top.id, fixture.bottom.id])
}

@Test("Nested composition cycles are rejected")
func nestedCyclesAreRejected() throws {
    #expect(throws: ProjectError.self) { try ProjectDocument.directCycleFixture().validated() }
    #expect(throws: ProjectError.self) { try ProjectDocument.indirectCycleFixture().validated() }
}
```

Also test duplicate IDs, ownership mismatch, missing references, invalid timing, non-finite transforms, model-only restrictions, and unsupported blend decoding.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter ProjectCompositionSchemaTests
```

Expected: missing schema 2 types.

- [ ] **Step 3: Implement exact public types**

```swift
public struct ProjectRGBAColor: Codable, Equatable, Sendable {
    public var red: Double; public var green: Double
    public var blue: Double; public var alpha: Double
    public func validated() throws -> Self
}

public struct ProjectComposition: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID; public var name: String
    public var width: Int; public var height: Int
    public var duration: RationalTime; public var frameRate: RationalTime
    public var color: ColorDescriptor; public var backgroundColor: ProjectRGBAColor
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
    public var positionX: Double; public var positionY: Double
    public var anchorX: Double; public var anchorY: Double
    public var scaleX: Double; public var scaleY: Double
    public var rotationDegrees: Double; public var opacity: Double
    public static let identity = LayerTransform(
        positionX: 0.5, positionY: 0.5, anchorX: 0.5, anchorY: 0.5,
        scaleX: 1, scaleY: 1, rotationDegrees: 0, opacity: 1
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
    case null, guide
    case camera(CameraLayerSettings)
    case light(LightLayerSettings)
    case composition(compositionID: VertexID, sourceStartTime: RationalTime)
}

public struct ProjectLayer: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID; public var compositionID: VertexID
    public var name: String; public var source: LayerSource
    public var enabled: Bool; public var locked: Bool; public var solo: Bool
    public var timing: LayerTiming; public var transform: LayerTransform
    public var blendMode: LayerBlendMode; public var operations: [LayerOperation]
}
```

Camera fields: projection, focal length, near/far clip, position XYZ, point-of-interest XYZ. Light fields: kind, RGBA, intensity, position XYZ, direction XYZ, cone angle, cone feather. Apply approved finite/range checks and model-only restrictions.

- [ ] **Step 4: Upgrade root schema and new-project creation**

```swift
public static let currentSchemaVersion = 2
public static let currentAppVersion = "6.0.0"

public var compositionRegistry: [ProjectComposition]
public var layerRegistry: [ProjectLayer]
public var activeCompositionID: VertexID?
public var selectedLayerID: VertexID?
public var selectedMediaID: VertexID?
public var legacyRenderSettings: ProjectRenderSettings?
```

`ProjectDocument.makeNew` deterministically creates one empty `Main Composition`, makes it active, and creates no fake layer. Add:

```swift
public func composition(id: VertexID) -> ProjectComposition?
public func layer(id: VertexID) -> ProjectLayer?
public func layers(in compositionID: VertexID) -> [ProjectLayer]
public func nestedCompositionCycle() -> [VertexID]?
```

`normalized()` sorts registries/applied command IDs, never `layerIDs`. `validated()` checks all root and graph invariants.

- [ ] **Step 5: Run GREEN and codec regressions**

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

### Task 2: Deterministic Schema 1 → 2 Migration

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

**Interfaces:** Produces stable derived IDs, package-visible schema 1 DTO/replay contracts, and registered `Schema1To2Migrator`.

- [ ] **Step 1: Write failing migration tests**

```swift
@Test("Selected schema 1 media becomes one deterministic media layer")
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

@Test("No selected media preserves legacy values without fake layer")
func noSelectionPreservesLegacyValues() throws {
    let input = try Fixture.data("schema1-no-composition.json")
    let result = try ProjectMigrationRegistry.current.migrate(input, from: 1, to: 2)
    let project = try DeterministicProjectCodec().decode(result.data)
    #expect(project.compositionRegistry.count == 1)
    #expect(project.layerRegistry.isEmpty)
    #expect(project.legacyRenderSettings != nil)
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter ProjectSchemaMigrationTests
```

Expected: no 1→2 migrator.

- [ ] **Step 3: Add exact stable ID APIs**

```swift
public init(uuidBytes: [UInt8]) throws
public static func digest(_ data: Data) -> [UInt8]

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

Freeze exact domain/vector output IDs in tests.

- [ ] **Step 4: Freeze schema 1 wire types with Swift `package` access**

`Schema1Compatibility.swift` defines `package` schema 1 project, render settings, placeholder, operation, command, history, manifest, and journal types. `package` access permits `VertexProjectFoundation` to read them without exposing them as public writable API.

```swift
package struct Schema1RecoveredState: Sendable {
    package var document: Schema1ProjectDocument
    package var lastJournalSequence: UInt64
}

package struct Schema1JournalReplayer {
    package func replay(
        _ records: [Schema1JournalRecord],
        onto document: Schema1ProjectDocument,
        startingAfter sequence: UInt64
    ) throws -> Schema1RecoveredState
}
```

Implement all Phase 5 operation preconditions in a schema 1 command engine.

- [ ] **Step 5: Implement and register migrator**

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

Reuse placeholder IDs; otherwise derive `Main Composition`. Use old dimensions/frame rate/color, ten exact seconds, transparent background, full In/Out. Move selected media plus old static Render Lab values into one media layer; otherwise preserve `legacyRenderSettings`.

- [ ] **Step 6: Run GREEN and full project regressions**

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

### Task 3: Composition/Layer Commands and History

**Files:**
- Create: `Sources/VertexProject/ProjectCommandPayloads.swift`
- Create: `Sources/VertexProject/ProjectDuplicationFactory.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectHistory.swift`
- Create: `Tests/VertexProjectTests/ProjectCompositionCommandTests.swift`
- Create: `Tests/VertexProjectTests/ProjectLayerCommandTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectCommandTests.swift`

**Interfaces:** Produces exact reversible composition/layer operations and deterministic duplication payloads.

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
```

Add tests for every approved composition/layer command, exact preconditions, locked edit refusal except unlock, referenced composition deletion, source cycle rejection, journal preparation failure, and duplication remapping.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter ProjectCompositionCommandTests
swift test --filter ProjectLayerCommandTests
```

Expected: missing operations.

- [ ] **Step 3: Implement operation cases**

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

Camera/light edits use `setLayerSource`. `ProjectDuplicationFactory` derives all IDs before recording and remaps only nested references internal to the duplicated payload.

- [ ] **Step 4: Implement inverse/preconditions/coalescing**

Apply full-document validation after every operation. Coalesce chained transform/timing/operations only when project, layer, merge key, time window, and previous-after/current-before match. Blend changes have no merge key. Failed undo/redo preparation preserves project bytes, Z-order, selection, and stack counts.

- [ ] **Step 5: Run GREEN**

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

### Task 4: Package Migration, Autosave, and Recovery

**Files:**
- Create: `Sources/VertexProjectFoundation/Schema1PackageReader.swift`
- Create: `Sources/VertexProjectFoundation/ProjectPackageMigrator.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectPackageStore.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectRecovery.swift`
- Modify: `Sources/VertexProjectFoundation/ProjectAutosaveStore.swift`
- Create: `Tests/VertexProjectFoundationTests/ProjectPackageMigrationTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectPackageStoreTests.swift`
- Modify: `Tests/VertexProjectFoundationTests/ProjectRecoveryTests.swift`

**Interfaces:** Produces schema-aware opening and a separate schema 2 working package.

- [ ] **Step 1: Write failing package tests**

```swift
@Test("Schema 1 migration preserves source and resets incompatible history")
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

Add destination write failure and future schema no-rewrite tests.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter ProjectPackageMigrationTests
```

Expected: missing migrator.

- [ ] **Step 3: Implement schema 1 package reader**

Use Task 2 `package` DTOs. Verify project/manifest checksum and identity, decode history/journal, replay complete records newer than committed sequence, and return one recovered logical schema 1 snapshot without writing source files.

- [ ] **Step 4: Implement final services**

```swift
public struct ProjectPackageMigrationResult: Sendable {
    public var sourcePackageURL: URL
    public var migratedPackageURL: URL
    public var reports: [ProjectMigrationReport]
    public var loadResult: ProjectPackageLoadResult
}

public struct ProjectPackageMigrator {
    public func migrate(schema1PackageURL: URL, destinationURL: URL) throws -> ProjectPackageMigrationResult
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

Sequence: verify/replay schema 1 → migrate canonical bytes → decode/validate schema 2 → create destination with empty history/journal sequence 0 → readback/checksum. Delete partial destination on failure; preserve source.

- [ ] **Step 5: Add schema 2 persistence regressions**

Assert ownership/Z-order survive save/reopen, autosave rotation, backup recovery, and recovered-package creation. Mismatched backup history opens empty.

- [ ] **Step 6: Run GREEN**

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

**Interfaces:** Produces ordered node-local evaluation and deterministic composition cache context.

- [ ] **Step 1: Write failing DAG tests**

```swift
@Test("Composite dependencies remain backdrop then source")
func compositeOrderIsSemantic() throws {
    let graph = try RenderGraph.twoSourceFixture(blendMode: .multiply)
    let node = try #require(try graph.evaluationPlan().orderedNodes.first {
        if case .composite = $0.kind { return true }; return false
    })
    #expect(node.dependencies == [RenderGraph.fixtureBackdropID, RenderGraph.fixtureSourceID])
}

@Test("Disconnected nodes fail")
func disconnectedNodesFail() {
    #expect(throws: RenderError.self) { try RenderGraph.disconnectedFixture().evaluationPlan() }
}
```

Also test multiple sources, local operations, arity, missing dependency, cycle, and cache context changes.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter RenderMultiSourceTests
```

Expected: missing DAG types.

- [ ] **Step 3: Implement graph/cache values**

```swift
public struct RenderRGBAColor: Codable, Equatable, Sendable {
    public var red: Double; public var green: Double
    public var blue: Double; public var alpha: Double
}

public enum RenderSource: Codable, Equatable, Sendable {
    case image(PortableImage)
    case solidColor(RenderRGBAColor)
}

public enum RenderBlendMode: String, Codable, CaseIterable, Sendable {
    case normal, add, multiply, screen
}

public struct RenderTransform2D: Codable, Equatable, Sendable {
    public var positionX: Double; public var positionY: Double
    public var anchorX: Double; public var anchorY: Double
    public var scaleX: Double; public var scaleY: Double
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

Add `transform2D(RenderTransform2D)` to `RenderOperation`.

- [ ] **Step 4: Implement evaluation plan and metrics compatibility**

```swift
public struct RenderEvaluationPlan: Equatable, Sendable {
    public var orderedNodes: [RenderNode]
    public var outputNodeID: VertexID
    public var consumerCounts: [VertexID: Int]
}

public func evaluationPlan() throws -> RenderEvaluationPlan
```

Arity: source 0, operations 1, adjustment 1, composite 2 ordered `[backdrop, source]`, output 1. Reject duplicate/missing/disconnected/cyclic nodes.

`RenderMetrics` final stored fields include `expandedNodeCount`, `renderedLayerCount`, and `estimatedPeakTextureBytes`. Preserve source compatibility with:

```swift
public var estimatedTextureBytes: Int { estimatedPeakTextureBytes }
```

The initializer defaults new counts/peak bytes to `0` until Task 7 supplies them. Add optional `RenderCacheContext` to `RenderRequest` and include it in cache bytes.

- [ ] **Step 5: Run GREEN**

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

**Interfaces:** Produces `CompositionGraphCompiler.compile` and platform-free exact frame resolution.

- [ ] **Step 1: Wire product/target and module source**

```swift
.library(name: "VertexComposition", targets: ["VertexComposition"])
.target(name: "VertexComposition", dependencies: ["VertexCore", "VertexMedia", "VertexProject", "VertexRender"])
.testTarget(name: "VertexCompositionTests", dependencies: ["VertexComposition", "VertexProject", "VertexRender", "VertexMedia", "VertexCore"])
```

Create `CompositionModule.swift` before running tests; add app/test product dependencies to `project.yml`.

- [ ] **Step 2: Write failing compiler tests against final contracts**

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

Test bottom-to-top order, enabled/timing/Solo, participating-only missing media, negative time transparency, adjustment placement, nested offset/bounds, frame deduplication, cycles, limits, cancellation, and cache context.

- [ ] **Step 3: Verify RED**

```bash
swift test --filter VertexCompositionTests
```

Expected: missing compiler implementation.

- [ ] **Step 4: Implement visibility and recursive compiler**

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

Start with `RenderSource.solidColor`; traverse authoritative IDs bottom-to-top; cache media by ID+exact time+target size; recurse nested compositions with ID stack; add adjustment over current accumulator; derive deterministic node IDs; enforce all limits. Negative media time and child-out-of-range produce transparency without I/O.

- [ ] **Step 5: Run GREEN and full portable regression**

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

### Task 7: Metal DAG and Premultiplied Blending

**Files:**
- Create: `Sources/VertexRenderMetal/MetalRenderParameters.swift`
- Create: `Sources/VertexRenderMetal/MetalTexturePool.swift`
- Create: `Sources/VertexRenderMetal/MetalGraphExecutor.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderBackend.swift`
- Modify: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Create: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`
- Modify: `Tests/VertexRenderMetalTests/MetalRenderBackendTests.swift`

**Interfaces:** Produces premultiplied RGBA8 solid/layer/composite/adjustment execution and last-use texture reuse.

- [ ] **Step 1: Write failing native pixel tests**

`PixelFixture.premultipliedRGBA` decodes the output PNG into the same premultiplied RGBA8 representation used by `MetalImageCodec`.

```swift
@Test("Multiply follows semitransparent alpha formula")
func multiplyPremultipliedAlpha() async throws {
    let request = try RenderFixture.twoSourceRequest(
        backdrop: .rgba(128, 64, 32, 128),
        source: .rgba(64, 128, 255, 128),
        blend: .multiply
    )
    let result = try await MetalRenderBackend().render(request, cancellationToken: .init())
    #expect(try PixelFixture.premultipliedRGBA(result.image) == [56, 56, 80, 192])
}

@Test("Transparent RGB cannot contaminate backdrop")
func transparentRGBDoesNotLeak() async throws {
    let result = try await MetalRenderBackend().render(
        try RenderFixture.transparentContaminationRequest(), cancellationToken: .init()
    )
    #expect(try PixelFixture.premultipliedRGBA(result.image) == [40, 80, 120, 255])
}
```

Freeze exact fixtures for all four blends, transform components, opacity, operations, adjustment mix, two sources, and nested graph.

- [ ] **Step 2: Verify RED on macOS**

```bash
swift test --filter MetalCompositionPixelTests
```

Expected: missing pipelines/executor.

- [ ] **Step 3: Implement resources and shader parameters**

Load `vertexSolidKernel`, `vertexLayerKernel`, `vertexCompositeKernel`, `vertexAdjustmentKernel`. Swift and Metal parameter structs have identical field order/alignment; native tests assert exact `MemoryLayout.stride`.

- [ ] **Step 4: Implement shader semantics**

Solid fills premultiplied RGBA. Layer performs inverse anchor/position/scale/rotation sampling, exposure, saturation, invert, opacity, premultiplication. Composite uses ordered backdrop/source and approved formulas. Adjustment safely unpremultiplies, applies operations, premultiplies, and mixes by opacity.

- [ ] **Step 5: Implement pool/executor**

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

Evaluate node-local operations; decrement consumers; release after last use; read back only output; populate final metrics.

- [ ] **Step 6: Replace old flattened backend and run GREEN**

Delete `sourceImage()`/`flattenedOperations()` after backend compilation succeeds.

```bash
swift test --filter VertexRenderMetalTests
swift test --filter VertexRenderTests
swift test --filter VertexCompositionTests
xcrun -sdk macosx metal -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal -o /tmp/VertexRenderKernels.air
```

Expected: all pass; Metal compile exit 0.

- [ ] **Step 7: Commit**

```bash
git add Sources/VertexRenderMetal Tests/VertexRenderMetalTests
git commit -m "feat: execute composition graphs with Metal"
```

---

### Task 8: App Media Adapter and Exact Preview

**Files:**
- Create: `App/CompositionMediaFrameResolver.swift`
- Create: `App/CompositionPreviewController.swift`
- Create: `App/ProjectWorkspaceCompositionCommands.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/MediaImportView.swift`
- Modify: `App/ProjectPackageFileDocument.swift`

**Interfaces:** Produces app-only media resolution, durable typed operations, exact navigation, latest render, last-success retention, and PNG payload.

- [ ] **Step 1: Implement exact media adapter**

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

Resolution: verified embedded → valid bookmark → missing-media error. AVFoundation receives exact time and target size.

- [ ] **Step 2: Expose durable command entry**

```swift
@MainActor
func applyProjectOperation(_ operation: ProjectOperation, mergeKey: String? = nil)
```

Order: validate → journal append/synchronize → history perform → publish → autosave. Add typed methods for all Phase 6 operations.

- [ ] **Step 3: Make opening schema-aware and media import layer-based**

Use `ProjectPackageOpeningService`: schema 1 opens a distinct migrated package; schema 2 opens directly; future schema is not rewritten. Media import registers media and inserts a real media layer. `legacyRenderSettings` remains read-only.

- [ ] **Step 4: Implement exact preview controller**

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

Convert index to exact time; cancel prior compile/render; compile; use `LatestRenderCoordinator`; publish matching generation only; retain previous success on failure.

- [ ] **Step 5: Run tests and app Debug build**

```bash
swift test
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Debug \
  -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat: connect composition media and exact preview"
```

---

### Task 9: Functional Composition Workspace

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

**Interfaces:** Produces real composition/layer editing and exact preview without a fake timeline.

- [ ] **Step 1: Build composition header**

Active picker; create/duplicate/rename/delete; dimensions, frame rate, duration, background. Each accepted edit emits one durable command. Referenced delete reports error without mutation.

- [ ] **Step 2: Build exact frame navigator**

First/previous/next/last, direct integer entry, and scrub converted immediately to clamped integer frame.

- [ ] **Step 3: Build layer list**

Top row is top Z-order. Show source, name, enabled, lock, Solo, current activity, blend, missing, and `Model only`. One move emits one reorder. Add Media, Adjustment, Null, Guide, Camera, Light, and cycle-safe Nested Composition.

- [ ] **Step 4: Build inspector**

Expose supported name/flags/timing/transform/blend/operations/nested/camera/light fields. Locked layers expose only unlock. Camera/light show `No Phase 6 output effect`.

Merge keys:

```text
layer.<id>.transform.position
layer.<id>.transform.scaleX
layer.<id>.transform.scaleY
layer.<id>.transform.rotation
layer.<id>.timing
layer.<id>.operations.exposure
layer.<id>.operations.saturation
```

Blend uses no merge key.

- [ ] **Step 5: Assemble workspace and replace Render Lab**

Show checkerboard, last image, progress, current error, metrics, and PNG from identical result bytes. Preserve project Open/Save/Export, Undo/Redo, autosave, relink, embed, recovery. Media import adds a layer. Delete old Render Lab files only after `git grep RenderLab` finds no production/test reference except historical docs.

- [ ] **Step 6: Compile and commit**

```bash
xcodegen generate
xcodebuild -project Vertex.xcodeproj -scheme Vertex -configuration Debug \
  -sdk iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
git add App
git commit -m "feat: add composition and layer workspace"
```

Expected: build exit 0.

---

### Task 10: Integration, CI, Documentation, and IPA

**Files:**
- Modify: `Package.swift`, `project.yml`, `.github/workflows/phase-build.yml`
- Modify: `Sources/VertexCore/Milestone.swift`, `Sources/VertexProject/ProjectModule.swift`
- Modify: `README.md`, `Documentation/VERSIONING_AND_ARTIFACTS.md`, `Documentation/HANDOFF.md`
- Create: `Documentation/LAYERS_COMPOSITIONS_ARCHITECTURE.md`
- Create: `Documentation/COMPOSITION_TEST_MATRIX.md`
- Create: `Documentation/PHASE_6_WORK_LOG.md`
- Create after verified build: `Documentation/PHASE_6_COMPLETION.md`

**Interfaces:** Produces verified source/CI evidence and unsigned IPA.

- [ ] **Step 1: Set truthful version/milestone**

```yaml
MARKETING_VERSION: 6.0.0
CURRENT_PROJECT_VERSION: 6
```

Update deliverables without excluded claims.

- [ ] **Step 2: Update CI**

Linux `swift test`. macOS:

```bash
swift test --filter VertexProjectFoundationTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
xcrun -sdk macosx metal -c Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal -o "$RUNNER_TEMP/VertexRenderKernels.air"
```

Build unsigned iOS Release; verify display name, bundle ID, arm64, `6.0.0 (6)`, `Assets.car`, `default.metallib`. Package exactly:

```bash
zip -qry artifacts/After-Effects-6.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/After-Effects-6.0.0-unsigned.ipa \
  > artifacts/After-Effects-6.0.0-unsigned.ipa.sha256
```

Artifact name `After-Effects-6.0.0-unsigned-ipa`.

- [ ] **Step 3: Run fresh full verification**

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

Expected: zero failures and build exit 0. Record exact counts.

- [ ] **Step 4: Verify final Actions artifact**

Use final product/CI HEAD. Confirm all jobs, download that artifact, and inspect:

```text
Payload/AfterEffects.app/AfterEffects
Mach-O 64-bit arm64
CFBundleDisplayName = After Effects
CFBundleIdentifier = com.woo642778.aftereffects
CFBundleShortVersionString = 6.0.0
CFBundleVersion = 6
MinimumOSVersion = 17.0
Assets.car exists
default.metallib exists
```

Calculate ZIP SHA-256, IPA SHA-256, IPA size, resource sizes; compare `.sha256`.

- [ ] **Step 5: Write exact completion evidence**

Record product/CI commit, run ID, artifact ID, digests, test counts, identity, implemented/excluded behavior, and unverified physical-device/manual scenarios. Documentation paths remain ignored to prevent checksum loops.

- [ ] **Step 6: Audit stale claims and spec coverage**

```bash
git grep -nE '5\.0\.0|CURRENT_PROJECT_VERSION: 5|SCHEMA 1|ProjectCompositionPlaceholder|global Render Lab'
```

Expected: intentional historical/schema1 fixture matches only. Map every approved design requirement to passing test, real UI behavior, or explicit exclusion/model-only statement.

- [ ] **Step 7: Update handoff/PR and commit**

Document branch/PR, schema 2, migration, modules, evidence, current behavior, exclusions, and Phase 7 design gate. Keep PR Draft/unmerged.

```bash
git add .github Package.swift project.yml Sources App Tests README.md Documentation docs
git commit -m "docs: complete Phase 6 verification and handoff"
```
