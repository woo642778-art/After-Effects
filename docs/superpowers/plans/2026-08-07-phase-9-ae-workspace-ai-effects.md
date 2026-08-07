# Vertex2 9.0 AE-Style Workspace and AI Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Vertex2 9.0.0 as a native iPad-first AE-style editor with a real professional layer timeline, ordered non-destructive AI effects, current-frame AI preview/cache scheduling, transactional Extract/Bake-to-Layer, iPhone compact adaptation, schema-5 persistence, and a verified unsigned IPA.

**Architecture:** Keep the established `ProjectLayer -> CompositionGraphCompiler -> RenderGraph -> MetalGraphExecutor` path. Add exact-time timeline primitives and commands in `VertexProject`/`VertexTimeline`, a minimal typed `ProjectEffect` stack persisted on layers, an async `CompositionEffectResolver` boundary between decoded source frames and masks/transforms, and an app-owned `AIFrameEffectService` that reuses the existing Core ML/Vision backends. UI becomes one shared editor workspace state rendered as a four-panel iPad layout or compact iPhone layout; no UI view performs decode, inference, or pixel processing directly.

**Tech Stack:** Swift 6, SwiftUI, Swift Concurrency, AVFoundation, Core ML, Vision, Metal, Swift Testing/XCTest, XcodeGen, GitHub Actions, existing Vertex2 exact `RationalTime` and `.vertexproject` persistence.

## Global Constraints

- Product: `Vertex2`.
- Target release: `9.0.0`, build `9`.
- Target artifact: `Vertex2-9.0.0-unsigned.ipa`.
- Bundle identifier remains `com.woo642778.aftereffects`.
- Minimum iOS target remains iOS 17; do not change signing, entitlements, bundle ID, provisioning, or deployment target.
- Primary editor: iPad landscape. iPhone uses the same project/engine state with compact panels.
- Native Swift/SwiftUI/AVFoundation/Core ML/Vision/Metal only; no Flutter, React Native, Electron, or web editing engine.
- All canonical edit times use `RationalTime`; view-space floating-point coordinates are projections only.
- All project mutations use project commands and participate in validation, undo/redo, autosave, and deterministic persistence.
- `ProjectLayer -> CompositionGraphCompiler -> RenderGraph -> MetalGraphExecutor` remains the rendering backbone.
- AI effects are non-destructive. Disabling/deleting an AI effect must expose the pre-effect layer without modifying source media.
- AI preview may use a lower quality/resolution tier; preview and export share effect semantics and export may not silently substitute original pixels for a required AI result.
- Runtime AI cache is not canonical project media. Only explicit Extract/Bake registers durable derived media.
- Existing schema-4 masks, mattes, animation channels, AI assets, and persistence invariants must survive schema-5 migration.
- Existing Phase-7 AI model license/digest audit remains a release gate. Do not bundle non-compatible weights.
- Natron/Olive GPL implementation code is reference-only. Do not copy GPL code into Vertex2.
- Do not expose controls that have no backing engine behavior.
- No placeholder implementations, fake progress, silent catch/fallback, duplicate effect paths, hardcoded local paths, or claimed success without test/build evidence.

---

## File Map

### New project/timeline files

- `Sources/VertexProject/ProjectTimeline.swift` — persisted work area, markers, parent link, expanded layer timing/source-offset model.
- `Sources/VertexProject/ProjectEffect.swift` — typed/versioned ordered effect instances and canonical parameters.
- `Sources/VertexProject/Schema4To5Migrator.swift` — deterministic migration from 8.0 schema 4 to 9.0 schema 5.
- `Sources/VertexTimeline/TimelineEdit.swift` — pure exact-time edit request/result types.
- `Sources/VertexTimeline/TimelineEngine.swift` — split/trim/move/ripple/roll/slip/slide algorithms.
- `Sources/VertexTimeline/TimelineSnapEngine.swift` — deterministic snap candidates and nearest-target resolution.
- `Sources/VertexTimeline/TimelineSelection.swift` — selection set and range transforms independent of SwiftUI.

### New composition/effect files

- `Sources/VertexComposition/CompositionEffectResolver.swift` — async effect boundary used by compiler.
- `Sources/VertexComposition/EffectAnimationEvaluator.swift` — exact-time effect-parameter evaluation.

### New AI effect files

- `Sources/VertexAI/AIFrameEffectKey.swift` — canonical single-frame effect cache identity.
- `Sources/VertexAI/AIFrameEffectTypes.swift` — request/result/status and scheduling priority types.
- `App/AIFrameEffectService.swift` — actor-backed scheduler, memory/disk cache orchestration, cancellation.
- `App/BundledAIEnvironment+FrameEffects.swift` — adapters from project effect recipes to existing AI backends.
- `App/CompositionEffectResolverAdapter.swift` — app bridge that resolves effects during composition compilation.
- `App/AIEffectBakeCoordinator.swift` — durable full-range processing followed by atomic project registration.

### New editor UI files

- `App/EditorWorkspaceState.swift` — shared selection/playhead/tool/panel state.
- `App/VertexEditorWorkspaceView.swift` — device-adaptive editor root.
- `App/IPadEditorWorkspaceView.swift` — Project / Viewer / Effect Controls / Timeline panel layout.
- `App/IPhoneEditorWorkspaceView.swift` — compact Viewer + Timeline + drawers.
- `App/AETimelineView.swift` — layer rows, ruler, playhead, zoom, edit gestures.
- `App/AETimelineLayerRow.swift` — switches/columns/disclosure/property rows.
- `App/EffectControlsView.swift` — ordered effect stack, parameters, enabled/reorder/delete.
- `App/AIEffectControlsView.swift` — Depth/Cutout/Upscale/Restore parameters, cache state, Extract/Bake.
- `App/GraphEditorView.swift` — Value/Speed graph editor for existing animation channels.

### Existing files modified

- `Package.swift`, `Package@swift-6.0.swift` — add `VertexTimeline` target/product and test target.
- `Sources/VertexProject/ProjectLayer.swift` — source offset/timing compatibility, parent link, effect stack.
- `Sources/VertexProject/ProjectComposition.swift` — work area and composition markers.
- `Sources/VertexProject/ProjectAnimation.swift` — effect parameter property address support.
- `Sources/VertexProject/ProjectSchema.swift` — schema 5, app version 9.0.0.
- `Sources/VertexProject/ProjectMigration.swift` — register 4->5 migration.
- `Sources/VertexProject/ProjectCommandPayload.swift` — timeline/effect/bake command payloads.
- `Sources/VertexProject/ProjectMutation.swift` — reversible mutations for new payloads.
- `Sources/VertexProject/ProjectCommands.swift` — validation/apply/inverse implementation.
- `Sources/VertexComposition/CompositionTypes.swift` — effect resolver protocol input/output types where shared.
- `Sources/VertexComposition/CompositionGraphCompiler.swift` — apply ordered effects before masks and preserve matte-source behavior.
- `App/CompositionPreviewController.swift` — shared playhead render requests and rerender when AI result changes.
- `App/ProjectWorkspaceViewModel.swift` — wrappers for timeline/effect/bake project commands.
- `App/RootView.swift` — replace stacked composition/editor cards with new editor workspace.
- `App/AIWorkspaceView.swift`, `App/AIWorkspaceViewModel.swift` — retain legacy utility only where still useful; layer workflow becomes primary and duplicate user-facing flow is removed from root.
- `Sources/VertexCore/Milestone.swift` — Phase 9 release state.
- `project.yml` — 9.0.0/build 9 and test-host consistency.
- `.github/workflows/phase-build.yml` — Phase 9 tests/audits and 9.0 artifact naming.

---

### Task 1: Add Schema-5 Timeline and Parent Primitives

**Files:**
- Create: `Sources/VertexProject/ProjectTimeline.swift`
- Create: `Sources/VertexProject/Schema4To5Migrator.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift` (`LayerTiming`, `ProjectLayer`, validation/Codable)
- Modify: `Sources/VertexProject/ProjectComposition.swift` (`ProjectComposition`, validation/Codable)
- Modify: `Sources/VertexProject/ProjectSchema.swift` (`ProjectDocument.currentSchemaVersion/currentAppVersion`)
- Modify: `Sources/VertexProject/ProjectMigration.swift` (migration registry)
- Test: `Tests/VertexProjectTests/ProjectTimelineSchemaTests.swift`
- Test: `Tests/VertexProjectTests/Schema4To5MigrationTests.swift`

**Interfaces:**
- Produces:
  - `ProjectMarker(id:time:name:comment:)`
  - `ProjectWorkArea(start:end:)`
  - `LayerTiming.startTime`, `inPoint`, `outPoint`, `sourceOffset`
  - `ProjectLayer.parentLayerID: VertexID?`
  - `ProjectComposition.workArea: ProjectWorkArea?`
  - `ProjectComposition.markers: [ProjectMarker]`
  - `ProjectDocument.currentSchemaVersion == 5`
  - `ProjectDocument.currentAppVersion == "9.0.0"`

- [ ] **Step 1: Write schema tests that describe exact-time invariants**

```swift
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
```

- [ ] **Step 2: Run focused tests and confirm they fail before implementation**

Run:
```bash
swift test --filter ProjectTimelineSchemaTests
```
Expected: compile/test failure because schema-5 timeline types and `sourceOffset` do not exist.

- [ ] **Step 3: Implement exact timeline primitives**

Use the following public shapes:

```swift
public struct ProjectMarker: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var name: String
    public var comment: String
}

public struct ProjectWorkArea: Codable, Equatable, Sendable {
    public var start: RationalTime
    public var end: RationalTime

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard start >= .zero, start < end, end <= compositionDuration else {
            throw ProjectError.invalidValue("Work area must satisfy 0 <= start < end <= composition duration.")
        }
        return self
    }
}
```

Extend `LayerTiming` with `sourceOffset`. Decode a missing schema-4 value as `.zero`. Validate `sourceOffset >= .zero` but do not implement speed/retime semantics in Phase 9.

Add `parentLayerID` to `ProjectLayer` with decode default `nil`. Validate that the parent exists in the same composition, is not self, and that following `parentLayerID` links cannot cycle.

- [ ] **Step 4: Implement composition work area and markers**

Add optional work area and marker array with missing-key defaults so schema-4 documents can be decoded during migration. Validate marker IDs are unique and marker times are within `[0, composition.duration)`.

- [ ] **Step 5: Implement deterministic schema 4 -> 5 migration**

`Schema4To5Migrator` must preserve all schema-4 media, compositions, layers, animation channels, masks, mattes, and AI assets; initialize `sourceOffset = .zero`, `parentLayerID = nil`, empty marker arrays, nil/default work area, and set `lastSavedByAppVersion = "9.0.0"`.

- [ ] **Step 6: Run migration and codec tests**

Run:
```bash
swift test --filter Schema4To5MigrationTests
swift test --filter ProjectTimelineSchemaTests
swift test --filter VertexProjectTests
```
Expected: PASS; canonical encode -> decode -> encode remains deterministic.

- [ ] **Step 7: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat(project): add schema 5 timeline primitives"
```

---

### Task 2: Add a Pure Exact-Time Timeline Engine

**Files:**
- Create: `Sources/VertexTimeline/TimelineEdit.swift`
- Create: `Sources/VertexTimeline/TimelineEngine.swift`
- Modify: `Package.swift`
- Modify: `Package@swift-6.0.swift`
- Test: `Tests/VertexTimelineTests/TimelineEngineTests.swift`

**Interfaces:**
- Consumes: schema-5 `ProjectDocument`, `ProjectComposition`, `ProjectLayer`, `LayerTiming`.
- Produces:

```swift
public enum TimelineEdit: Equatable, Sendable {
    case move(layerIDs: [VertexID], delta: RationalTime)
    case trimIn(layerID: VertexID, to: RationalTime)
    case trimOut(layerID: VertexID, to: RationalTime)
    case split(layerID: VertexID, at: RationalTime)
    case ripple(layerID: VertexID, edge: TimelineEdge, to: RationalTime, affectedLayerIDs: [VertexID])
    case roll(leftLayerID: VertexID, rightLayerID: VertexID, boundary: RationalTime)
    case slip(layerID: VertexID, sourceDelta: RationalTime)
    case slide(layerID: VertexID, delta: RationalTime, previousLayerID: VertexID?, nextLayerID: VertexID?)
}

public struct TimelineEditResult: Equatable, Sendable {
    public var updatedLayers: [ProjectLayer]
    public var insertedLayers: [ProjectLayer]
    public var removedLayerIDs: [VertexID]
    public var resultingLayerOrder: [VertexID]
}
```

- [ ] **Step 1: Write failing edit-equivalence tests**

```swift
@Test func splitPreservesSourceContinuity() throws {
    let fixture = try TimelineFixtures.singleMediaLayer(start: .zero, durationSeconds: 10, sourceOffsetSeconds: 2)
    let result = try TimelineEngine().apply(
        .split(layerID: fixture.layer.id, at: RationalTime(value: 4, timescale: 1)),
        to: fixture.project,
        compositionID: fixture.composition.id
    )
    #expect(result.insertedLayers.count == 1)
    let right = try #require(result.insertedLayers.first)
    #expect(right.timing.sourceOffset == RationalTime(value: 6, timescale: 1))
    #expect(right.timing.inPoint == RationalTime(value: 4, timescale: 1))
}
```

Add focused tests for invalid trim, default non-ripple move, ripple scope, roll combined duration, slip preserving composition timing, and slide preserving selected-layer duration.

- [ ] **Step 2: Run tests and verify initial failure**

```bash
swift test --filter VertexTimelineTests
```
Expected: target/type missing.

- [ ] **Step 3: Add the `VertexTimeline` Swift package target**

Dependencies: `VertexCore`, `VertexProject`. The target must not depend on SwiftUI, AVFoundation, Core ML, or Metal.

- [ ] **Step 4: Implement one edit at a time, starting with move/trim/split**

All arithmetic uses `RationalTime.adding/subtracting`; reject operations that produce negative source offset, `inPoint >= outPoint`, or times outside composition duration. Split clones the source/effect/mask/animation state but gives the new right layer a new stable `VertexID` and partitions keyframes by exact time so render continuity is preserved.

- [ ] **Step 5: Implement ripple/roll/slip/slide with explicit eligibility**

Do not infer hidden ripple scopes. Only IDs in the request may be moved. Roll requires adjacent eligible source-backed layers and must keep the outer interval unchanged.

- [ ] **Step 6: Run all timeline engine tests**

```bash
swift test --filter VertexTimelineTests
```
Expected: PASS including all invalid-boundary tests.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Package@swift-6.0.swift Sources/VertexTimeline Tests/VertexTimelineTests
git commit -m "feat(timeline): add exact-time edit engine"
```

---

### Task 3: Add Snapping and Multi-Selection Math

**Files:**
- Create: `Sources/VertexTimeline/TimelineSnapEngine.swift`
- Create: `Sources/VertexTimeline/TimelineSelection.swift`
- Test: `Tests/VertexTimelineTests/TimelineSnapEngineTests.swift`
- Test: `Tests/VertexTimelineTests/TimelineSelectionTests.swift`

**Interfaces:**

```swift
public enum TimelineSnapKind: Hashable, Sendable {
    case playhead, layerIn, layerOut, compositionStart, compositionEnd, workAreaStart, workAreaEnd, keyframe, marker
}

public struct TimelineSnapCandidate: Hashable, Sendable {
    public var time: RationalTime
    public var kind: TimelineSnapKind
    public var ownerID: VertexID?
}

public struct TimelineSnapResult: Equatable, Sendable {
    public var snappedTime: RationalTime
    public var candidate: TimelineSnapCandidate?
}
```

- [ ] **Step 1: Write deterministic nearest-snap tests**

Test same-distance tie-breaking by stable kind/order and verify changing timeline zoom changes time tolerance only through the supplied `secondsPerPoint` conversion, not through hidden global UI state.

- [ ] **Step 2: Run tests to confirm failure**

```bash
swift test --filter TimelineSnapEngineTests
swift test --filter TimelineSelectionTests
```

- [ ] **Step 3: Implement snap engine as a pure value service**

The engine receives proposed exact time, candidate list, screen threshold in points, and exact `secondsPerPoint`; it returns either unchanged time or the deterministic nearest candidate.

- [ ] **Step 4: Implement selection sets and group deltas**

`TimelineSelection` stores selected layer IDs and selected keyframe IDs separately. Add/remove/toggle/range-selection methods must not know about SwiftUI gestures.

- [ ] **Step 5: Run timeline tests**

```bash
swift test --filter VertexTimelineTests
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexTimeline Tests/VertexTimelineTests
git commit -m "feat(timeline): add snapping and selection model"
```

---

### Task 4: Make Timeline Edits Transactional Project Commands

**Files:**
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectMutation.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Test: `Tests/VertexProjectTests/ProjectTimelineCommandTests.swift`

**Interfaces:**
- Add payloads:

```swift
case applyTimelineEdit(compositionID: VertexID, result: TimelineProjectMutation)
case setCompositionWorkArea(id: VertexID, workArea: ProjectWorkArea?)
case setCompositionMarkers(id: VertexID, markers: [ProjectMarker])
case setLayerMarkers(id: VertexID, markers: [ProjectMarker])
case setLayerParent(id: VertexID, parentLayerID: VertexID?)
```

`TimelineProjectMutation` belongs in `VertexProject`, not `VertexTimeline`, and is an explicit before/after patch that can be inverted without rerunning UI gesture math.

- [ ] **Step 1: Write undo/redo tests for a split and grouped move**

```swift
@Test func splitCommandUndoRestoresExactOriginalDocument() throws {
    let before = try ProjectFixtures.timelineProject()
    var session = try ProjectEditingSession(project: before)
    let prepared = try TimelineCommandFixtures.splitMutation(project: before)
    try session.perform(.fixture(project: before, payload: .applyTimelineEdit(compositionID: prepared.compositionID, result: prepared.mutation)))
    try session.undo()
    #expect(session.project.normalized() == before.normalized())
}
```

- [ ] **Step 2: Run and verify failure**

```bash
swift test --filter ProjectTimelineCommandTests
```

- [ ] **Step 3: Implement reversible mutations**

Each timeline gesture commits one command with a merge key such as `timeline.move.<selectionDigest>` or `timeline.trim.<layerID>`. Continuous drag updates may merge in the editing session; final state is exact-time validated.

- [ ] **Step 4: Add view-model wrappers**

Expose methods such as:

```swift
func commitTimelineEdit(_ edit: TimelineEdit, compositionID: VertexID) async throws
func setLayerParent(layerID: VertexID, parentLayerID: VertexID?) async throws
func setWorkArea(_ workArea: ProjectWorkArea?) async throws
```

The wrapper runs `TimelineEngine` off the view gesture path and sends only a validated project command to the session actor.

- [ ] **Step 5: Run project/session regression tests**

```bash
swift test --filter ProjectTimelineCommandTests
swift test --filter ProjectEditingSessionTests
swift test --filter ProjectCommandTests
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexProject App/ProjectWorkspaceViewModel.swift Tests/VertexProjectTests
git commit -m "feat(project): make timeline edits transactional"
```

---

### Task 5: Add a Typed Ordered Layer Effect Stack

**Files:**
- Create: `Sources/VertexProject/ProjectEffect.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectAnimation.swift`
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectMutation.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Test: `Tests/VertexProjectTests/ProjectEffectTests.swift`
- Test: `Tests/VertexProjectTests/ProjectEffectCommandTests.swift`

**Interfaces:**

```swift
public enum ProjectEffectType: String, Codable, CaseIterable, Sendable {
    case depthMap
    case cutout
    case upscale
    case restore
}

public enum ProjectEffectParameterValue: Codable, Equatable, Sendable {
    case scalar(Double)
    case integer(Int)
    case boolean(Bool)
    case text(String)
}

public struct ProjectEffectParameter: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var value: ProjectEffectParameterValue
}

public struct ProjectEffect: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var type: ProjectEffectType
    public var version: Int
    public var enabled: Bool
    public var parameters: [ProjectEffectParameter]
}
```

Extend `ProjectPropertyAddress` with `.effect(effectID: VertexID, parameterID: String, valueKind: ProjectAnimatableValueKind)` so effect scalar parameters can use the existing keyframe model.

- [ ] **Step 1: Write failing effect validation/order tests**

Cover duplicate effect IDs, duplicate parameter IDs, non-finite scalar values, unsupported parameter IDs per effect type, model/quality values, and stable order preservation through encode/decode.

- [ ] **Step 2: Run focused tests**

```bash
swift test --filter ProjectEffectTests
```

- [ ] **Step 3: Implement strict descriptors for the four AI effect types**

Define canonical parameter IDs in code, for example:

```swift
public enum DepthMapParameterID {
    public static let quality = "quality"
    public static let invert = "invert"
    public static let near = "near"
    public static let far = "far"
    public static let smoothing = "smoothing"
    public static let edgeRefinement = "edgeRefinement"
    public static let temporalSmoothing = "temporalSmoothing"
    public static let output = "output"
}
```

Validation must reject unknown IDs rather than silently ignore them.

- [ ] **Step 4: Add `effects: [ProjectEffect]` to `ProjectLayer`**

Schema-4 decode default is empty. Pixel effects are forbidden on null/guide/camera/light model-only layers. Adjustment layers may only accept effect types explicitly supported by the evaluator; for Phase 9 AI effects, reject them on adjustment layers.

- [ ] **Step 5: Add effect stack project commands**

Add `setLayerEffects`, `insertLayerEffect`, `removeLayerEffect`, `moveLayerEffect`, and `setLayerEffectEnabled`. Their inverses must restore exact order/parameters.

- [ ] **Step 6: Run tests**

```bash
swift test --filter ProjectEffectTests
swift test --filter ProjectEffectCommandTests
swift test --filter VertexProjectTests
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat(effects): add typed ordered layer effect stack"
```

---

### Task 6: Add Exact-Time Effect Evaluation to the Composition Compiler

**Files:**
- Create: `Sources/VertexComposition/CompositionEffectResolver.swift`
- Create: `Sources/VertexComposition/EffectAnimationEvaluator.swift`
- Modify: `Sources/VertexComposition/CompositionTypes.swift`
- Modify: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Test: `Tests/VertexCompositionTests/EffectGraphCompilerTests.swift`

**Interfaces:**

```swift
public struct CompositionEffectRequest: Sendable {
    public var projectID: VertexID
    public var projectRevision: UInt64
    public var compositionID: VertexID
    public var layerID: VertexID
    public var effect: ProjectEffect
    public var exactCompositionTime: RationalTime
    public var exactSourceTime: RationalTime
    public var input: PortableImage
    public var targetSize: VertexSize
    public var purpose: CompositionRenderPurpose
}

public enum CompositionRenderPurpose: Sendable {
    case interactivePreview
    case export
}

public protocol CompositionEffectResolver: Sendable {
    func resolve(_ request: CompositionEffectRequest) async throws -> PortableImage
}
```

- [ ] **Step 1: Write compiler tests for effect ordering**

Use a fake resolver that records effect IDs and mutates one known pixel value per effect. Assert:

1. enabled effects are called in array order;
2. disabled effects are skipped;
3. effects execute before mask/transform/matte semantics;
4. matte-source layers evaluate their own effects;
5. deleting the effect produces the same request graph/result as the pre-effect source path.

- [ ] **Step 2: Run tests and verify failure**

```bash
swift test --filter EffectGraphCompilerTests
```

- [ ] **Step 3: Implement parameter animation evaluation**

`EffectAnimationEvaluator` reads effect-addressed channels and returns a copy of the effect with exact-time parameter values. It must reject type mismatch and missing referenced effect IDs.

- [ ] **Step 4: Integrate resolver into compiler**

For media sources, after `CompositionFrameResolver.resolve` returns `PortableImage`, iterate enabled/evaluated effects and replace the working `PortableImage` with each effect result before emitting the `.source` render node. Then preserve existing order `Effects -> Masks -> Transform/operations -> Track Matte -> Composite`.

For nested compositions, Phase 9 AI effects must operate on the nested rendered output. If the current compiler cannot materialize a nested node back to `PortableImage`, reject AI effects on nested-composition layers with a validation error in Phase 9 rather than pretending they work.

- [ ] **Step 5: Run composition/mask/matte regressions**

```bash
swift test --filter EffectGraphCompilerTests
swift test --filter Phase8CompositionGraphTests
swift test --filter VertexCompositionTests
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VertexComposition Tests/VertexCompositionTests
git commit -m "feat(composition): evaluate layer effects before masks"
```

---

### Task 7: Build Canonical AI Frame Cache Identity and Scheduler Types

**Files:**
- Create: `Sources/VertexAI/AIFrameEffectKey.swift`
- Create: `Sources/VertexAI/AIFrameEffectTypes.swift`
- Test: `Tests/VertexAITests/AIFrameEffectKeyTests.swift`

**Interfaces:**

```swift
public struct AIFrameEffectKey: Codable, Equatable, Hashable, Sendable {
    public let sourceFingerprint: String
    public let exactTime: RationalTime
    public let modelID: String
    public let modelDigest: String
    public let effectType: String
    public let algorithmVersion: Int
    public let parameterDigest: String
    public let qualityTier: String
    public let width: Int
    public let height: Int
    public let orientationDigest: String
    public let colorDigest: String
    public var digest: String { get }
}

public enum AIFramePriority: Int, Comparable, Sendable {
    case background = 0
    case workArea = 1
    case playbackNeighbor = 2
    case currentFrame = 3
}
```

- [ ] **Step 1: Write cache-key invalidation tests**

Change one field at a time—exact time, model digest, parameter digest, tier, resolution, orientation/color—and assert `digest` changes. Reconstruct the same key and assert digest stability.

- [ ] **Step 2: Run tests to confirm failure**

```bash
swift test --filter AIFrameEffectKeyTests
```

- [ ] **Step 3: Implement canonical digest generation**

Use `StableAISHA256` and an explicitly ordered UTF-8 serialization. Do not use `Dictionary.description`, locale-sensitive number formatting, or `Hashable.hashValue`.

- [ ] **Step 4: Run AI unit tests**

```bash
swift test --filter AIFrameEffectKeyTests
swift test --filter VertexAITests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VertexAI Tests/VertexAITests
git commit -m "feat(ai): add deterministic frame effect cache keys"
```

---

### Task 8: Implement the Actor-Backed AI Frame Effect Service

**Files:**
- Create: `App/AIFrameEffectService.swift`
- Create: `App/BundledAIEnvironment+FrameEffects.swift`
- Create: `App/CompositionEffectResolverAdapter.swift`
- Modify: `App/BundledAIEnvironment.swift`
- Test: `Tests/VertexAppTests/AIFrameEffectServiceTests.swift`

**Interfaces:**

```swift
actor AIFrameEffectService {
    func resolve(
        request: AIFrameEffectRequest,
        priority: AIFramePriority
    ) async throws -> PortableImage

    func prefetch(_ requests: [AIFrameEffectRequest], priority: AIFramePriority) async
    func cancelObsolete(keeping keys: Set<AIFrameEffectKey>) async
    func purge(effectID: VertexID) async throws
}
```

- [ ] **Step 1: Write scheduler tests with a fake inference backend**

Verify current-frame requests start before queued background requests, duplicate keys coalesce to one inference, cancelled obsolete requests do not publish results, and a parameter digest change triggers a new inference.

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AIFrameEffectServiceTests
```
Expected: compile failure before service exists.

- [ ] **Step 3: Implement bounded memory/disk cache**

Use an actor-owned in-memory LRU bounded by byte cost and an Application Support cache directory under a `Vertex2/AIFrameEffects` namespace. Write completed cache entries atomically through temporary files. Cache metadata includes the full key digest and output dimensions.

- [ ] **Step 4: Adapt existing inference backends**

Map project effects to existing recipes:

- Depth Map -> `DepthRecipe` and `DepthInferenceEngine`.
- Cutout -> `CutoutRecipe` and `VisionCutoutEngine`.
- Upscale -> `UpscaleRecipe` and `UpscaleInferenceEngine`.
- Restore -> `RestorationRecipe` and `RestorationInferenceEngine`.

Do not duplicate model-loading logic already owned by `BundledAIEnvironment`/`AIModelRegistry`.

- [ ] **Step 5: Implement `CompositionEffectResolverAdapter`**

For interactive preview, return a cached result immediately when present. On a cache miss, await the current-frame inference for the exact frame; the UI separately shows `Computing` based on service status. For export, any inference error propagates with effect/layer/time context.

- [ ] **Step 6: Run app and native AI tests**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AIFrameEffectServiceTests
swift test --filter VertexAICoreMLTests
```
Expected: PASS where platform-compatible; native model tests remain gated as existing CI defines them.

- [ ] **Step 7: Commit**

```bash
git add App/AIFrameEffectService.swift App/BundledAIEnvironment+FrameEffects.swift App/CompositionEffectResolverAdapter.swift App/BundledAIEnvironment.swift Tests/VertexAppTests
git commit -m "feat(ai): add prioritized frame effect service"
```

---

### Task 9: Implement Transactional Extract / Bake to Layer

**Files:**
- Create: `App/AIEffectBakeCoordinator.swift`
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectMutation.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Test: `Tests/VertexProjectTests/AIEffectBakeCommandTests.swift`
- Test: `Tests/VertexAppTests/AIEffectBakeCoordinatorTests.swift`

**Interfaces:**

```swift
public struct ProjectAIEffectBakeRegistration: Equatable, Sendable {
    public var media: MediaReference
    public var aiAsset: ProjectAIAsset
    public var layer: ProjectLayer
    public var insertionIndex: Int
}
```

Add one payload:

```swift
case registerBakedAIEffect(ProjectAIEffectBakeRegistration)
```

- [ ] **Step 1: Write command atomicity tests**

Assert one command registers media + AI asset + inserted layer and one undo removes all three document registrations and restores selection/order exactly.

- [ ] **Step 2: Write coordinator failure tests**

With fake processing/finalization validators, force cancellation and malformed output. Assert no project command is sent before final media validation succeeds.

- [ ] **Step 3: Implement bake coordinator pipeline**

The coordinator performs full required range processing, finalizes a durable media file, validates readability/duration/frame count/package-relative path, builds `ProjectAIRecipeReference`, then sends exactly one `registerBakedAIEffect` command.

New layer timing must match the source layer's composition placement and source duration. Insert directly above the source layer. Default names are `<Source> • Depth`, `<Source> • Cutout`, `<Source> • Upscale`, `<Source> • Restore`.

- [ ] **Step 4: Run bake tests**

```bash
swift test --filter AIEffectBakeCommandTests
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AIEffectBakeCoordinatorTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/AIEffectBakeCoordinator.swift App/ProjectWorkspaceViewModel.swift Sources/VertexProject Tests
git commit -m "feat(ai): add atomic bake-to-layer workflow"
```

---

### Task 10: Add Shared Editor Workspace State and Device-Adaptive Shell

**Files:**
- Create: `App/EditorWorkspaceState.swift`
- Create: `App/VertexEditorWorkspaceView.swift`
- Create: `App/IPadEditorWorkspaceView.swift`
- Create: `App/IPhoneEditorWorkspaceView.swift`
- Modify: `App/RootView.swift`
- Modify: `App/CompositionPreviewController.swift`
- Test: `Tests/VertexAppTests/EditorWorkspaceStateTests.swift`

**Interfaces:**

```swift
@MainActor
final class EditorWorkspaceState: ObservableObject {
    @Published var playhead: RationalTime = .zero
    @Published var selectedLayerIDs: Set<VertexID> = []
    @Published var selectedKeyframeIDs: Set<VertexID> = []
    @Published var activeTool: TimelineTool = .selection
    @Published var snappingEnabled = true
    @Published var pixelsPerSecond: Double = 120
    @Published var graphMode: GraphEditorMode? = nil
    @Published var compactPanel: CompactEditorPanel = .timeline
}
```

- [ ] **Step 1: Write state synchronization tests**

Test selection updates, playhead clamping against active composition duration, switching active composition resets invalid selection, and iPhone/iPad presentation state does not modify the canonical project document.

- [ ] **Step 2: Run tests to verify failure**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing:VertexAppTests/EditorWorkspaceStateTests
```

- [ ] **Step 3: Implement adaptive workspace root**

`VertexEditorWorkspaceView` chooses iPad four-panel layout using horizontal size class/device idiom and iPhone compact layout otherwise. Both receive the same environment `ProjectWorkspaceViewModel`, `EditorWorkspaceState`, and preview controller.

- [ ] **Step 4: Reconnect composition preview to shared playhead**

Replace the independent frame-slider source of truth with exact `EditorWorkspaceState.playhead`. A project revision or published AI-result generation invalidates/rerenders the current preview frame.

- [ ] **Step 5: Replace old root editing cards**

`RootView` should present the Vertex2 editor workspace as the primary project editing surface. Do not show a second independent AI Studio that suggests AI results must be manually imported. Keep any legacy utility reachable only if it serves a non-duplicated diagnostic/export purpose.

- [ ] **Step 6: Run state/app startup tests**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing:VertexAppTests/EditorWorkspaceStateTests
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AppStartupStateTests
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add App/EditorWorkspaceState.swift App/VertexEditorWorkspaceView.swift App/IPadEditorWorkspaceView.swift App/IPhoneEditorWorkspaceView.swift App/RootView.swift App/CompositionPreviewController.swift Tests/VertexAppTests
git commit -m "feat(ui): add adaptive AE-style editor workspace shell"
```

---

### Task 11: Implement the AE-Style Timeline UI

**Files:**
- Create: `App/AETimelineView.swift`
- Create: `App/AETimelineLayerRow.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Modify: `App/IPhoneEditorWorkspaceView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Test: `Tests/VertexAppTests/AETimelineInteractionTests.swift`

**Interfaces:**
- Consumes `TimelineEngine`, `TimelineSnapEngine`, `TimelineSelection`, `EditorWorkspaceState`.
- Produces user gestures only through `ProjectWorkspaceViewModel.commitTimelineEdit` and existing/new project command wrappers.

- [ ] **Step 1: Add interaction tests against command spies**

Test that dragging a layer sends one final exact move command, trimming does not ripple by default, split uses playhead exact time, snapping chooses the engine result, and layer reorder changes composition `layerIDs` through a project command.

- [ ] **Step 2: Implement ruler/playhead/zoom and work area**

Draw tick marks from exact time projected through `pixelsPerSecond`. Dragging the playhead updates `EditorWorkspaceState.playhead`; it does not edit the project document. Work-area handles commit `setCompositionWorkArea`.

- [ ] **Step 3: Implement layer columns and disclosures**

Include visibility, solo, lock, name, parent, matte, blend mode, and disclosure groups for Transform, Masks, Effects. Do not add Shy/3D buttons unless backed by implemented semantics.

- [ ] **Step 4: Implement edit gestures**

Selection tool supports move/trim/multi-select/keyframe drag. A tool menu exposes Ripple/Roll/Slip/Slide. Split is available from toolbar/context action. Horizontal pinch/slider zoom and fit-composition/fit-selection change only view state.

- [ ] **Step 5: Implement keyboard commands where iPad hardware keyboard exists**

Space toggles playback request; J/K/L change transport intent; Command-modified selection and standard copy/paste commands route through app command handling. Keyboard absence must not remove touch equivalents.

- [ ] **Step 6: Run iPad/iPhone UI interaction tests**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing:VertexAppTests/AETimelineInteractionTests
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AETimelineInteractionTests
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add App/AETimelineView.swift App/AETimelineLayerRow.swift App/IPadEditorWorkspaceView.swift App/IPhoneEditorWorkspaceView.swift App/ProjectWorkspaceViewModel.swift Tests/VertexAppTests
git commit -m "feat(ui): add professional AE-style layer timeline"
```

---

### Task 12: Implement Effect Controls and Layer-Integrated AI UX

**Files:**
- Create: `App/EffectControlsView.swift`
- Create: `App/AIEffectControlsView.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Modify: `App/IPhoneEditorWorkspaceView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Test: `Tests/VertexAppTests/EffectControlsInteractionTests.swift`

**Interfaces:**
- Add view-model actions:

```swift
func addEffect(_ type: ProjectEffectType, to layerID: VertexID) async throws
func setEffectEnabled(layerID: VertexID, effectID: VertexID, enabled: Bool) async throws
func setEffectParameter(layerID: VertexID, effectID: VertexID, parameterID: String, value: ProjectEffectParameterValue) async throws
func moveEffect(layerID: VertexID, effectID: VertexID, to index: Int) async throws
func removeEffect(layerID: VertexID, effectID: VertexID) async throws
func bakeEffect(layerID: VertexID, effectID: VertexID) async throws
```

- [ ] **Step 1: Write interaction tests**

Assert add Depth creates a project effect, disabling it sends the command and preview resolver is subsequently bypassed, reordering changes project effect order, deleting removes it, and Bake invokes the bake coordinator without directly registering a layer from UI code.

- [ ] **Step 2: Implement generic Effect Controls stack**

Selected layer shows ordered effect cards. Each card supports enabled toggle, drag reorder, delete, disclosure, animation stopwatch for animatable scalar parameters, and explicit status.

- [ ] **Step 3: Implement Depth Map controls**

Expose model selection constrained to approved bundled models, preview/final quality, Invert, Near, Far, Smoothing, Edge Refinement, Temporal Smoothing, and supported Output mode. Parameter edits update project state and invalidate only keys whose canonical digest changes.

- [ ] **Step 4: Implement Cutout/Upscale/Restore controls**

Reuse existing validated recipe ranges. Show `Ready`, `Computing`, `Cached`, `Stale`, or `Failed`. When source pixels are temporarily shown because output is pending/failed, display that state instead of implying AI output is active.

- [ ] **Step 5: Add Extract / Bake controls**

Show progress sourced from the coordinator. Cancellation leaves no document registrations. Successful completion selects the new baked layer.

- [ ] **Step 6: Run effect UI tests**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing:VertexAppTests/EffectControlsInteractionTests
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add App/EffectControlsView.swift App/AIEffectControlsView.swift App/IPadEditorWorkspaceView.swift App/IPhoneEditorWorkspaceView.swift App/ProjectWorkspaceViewModel.swift Tests/VertexAppTests
git commit -m "feat(ui): integrate AI effects into effect controls"
```

---

### Task 13: Add Graph Editor and Parent/Matte Timeline Controls

**Files:**
- Create: `App/GraphEditorView.swift`
- Modify: `App/AETimelineLayerRow.swift`
- Modify: `App/AETimelineView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Test: `Tests/VertexAppTests/GraphEditorInteractionTests.swift`
- Test: `Tests/VertexProjectTests/ParentingValidationTests.swift`

**Interfaces:**

```swift
public enum GraphEditorMode: Sendable {
    case value
    case speed
}
```

Graph editing modifies `ProjectKeyframe.incomingTemporalHandle` / `outgoingTemporalHandle` on the existing animation channel; it must not create a second curve data model.

- [ ] **Step 1: Write cubic-handle tests**

Change a keyframe handle through the graph editor command path and verify `ProjectAnimationChannel.evaluatedValue(at:)` changes accordingly and survives codec round-trip.

- [ ] **Step 2: Implement Value Graph**

Map scalar value/time to canvas coordinates, draw selected channels, and make keyframe/Bezier handles draggable. Convert drags back into exact keyframe times and finite scalar values before command commit.

- [ ] **Step 3: Implement Speed Graph**

Derive segment speed from neighboring scalar keyframes and temporal handles. Editing handle influence modifies the same temporal Bezier handles and preserves increasing keyframe times.

- [ ] **Step 4: Add parent and matte row controls**

Parent picker/pick-whip sends `setLayerParent`; reject self/cycle. Track Matte picker continues to write the existing `ProjectTrackMatte` and uses the already-tested alpha/luma render path.

- [ ] **Step 5: Run tests**

```bash
swift test --filter ParentingValidationTests
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -only-testing:VertexAppTests/GraphEditorInteractionTests
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add App/GraphEditorView.swift App/AETimelineLayerRow.swift App/AETimelineView.swift App/ProjectWorkspaceViewModel.swift Tests
git commit -m "feat(motion): add graph editor and timeline parenting"
```

---

### Task 14: Verify Preview/Export Effect Parity and AI Failure Semantics

**Files:**
- Modify: `Sources/VertexComposition/CompositionError.swift`
- Modify: `App/CompositionEffectResolverAdapter.swift`
- Modify: `App/CompositionPreviewController.swift`
- Test: `Tests/VertexCompositionTests/EffectPreviewExportParityTests.swift`
- Test: `Tests/VertexAppTests/AIEffectFailureSemanticsTests.swift`

**Interfaces:**
- Export errors include layer ID, effect ID/type, and exact time.
- Interactive preview may expose original input only while reporting non-success status through the service/UI state.

- [ ] **Step 1: Write parity test using deterministic fake effect backend**

Compile/render the same project/time twice with `.interactivePreview` and `.export` at identical resolution/quality and assert pixel equality. Then run preview at lower tier and assert the evaluator receives the same effect parameter semantics even if pixels differ by quality.

- [ ] **Step 2: Write export-failure test**

Force one required AI frame to fail. Assert export throws an error containing layer/effect/time and does not return the source frame as success.

- [ ] **Step 3: Implement explicit preview/export behavior**

Keep fallback labeling/status in app state, not hidden inside `CompositionGraphCompiler`. Export never swallows resolver errors.

- [ ] **Step 4: Run parity and render regression tests**

```bash
swift test --filter EffectPreviewExportParityTests
swift test --filter VertexCompositionTests
swift test --filter VertexRenderMetalTests
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VertexAppTests/AIEffectFailureSemanticsTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VertexComposition App/CompositionEffectResolverAdapter.swift App/CompositionPreviewController.swift Tests
git commit -m "test(render): enforce effect preview export parity"
```

---

### Task 15: Version Vertex2 9.0 and Build the Release Gate

**Files:**
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `project.yml`
- Modify: `.github/workflows/phase-build.yml`
- Modify: `Tools/ai/audit_ipa.py` only if it currently hardcodes an older product/version contract; otherwise leave unchanged.
- Test: existing Swift/Xcode/AI/Metal test suites plus release audit.

**Interfaces:**
- Marketing version: `9.0.0`.
- Build: `9`.
- App display/product name: `Vertex2`.
- Artifact: `Vertex2-9.0.0-unsigned.ipa`.

- [ ] **Step 1: Update milestone/version metadata**

Set the current milestone to Phase 9 Professional Timeline / AE Workspace + Layer AI Effects, version `9.0.0`, build `9`. Keep bundle ID and iOS target unchanged.

- [ ] **Step 2: Regenerate project and inspect schemes**

Run:
```bash
./Tools/generate_app_assets.sh
xcodegen generate
xcodebuild -list -project Vertex.xcodeproj
```
Expected: Vertex app/test schemes are listed and test host points at `Vertex2.app/Vertex2`.

- [ ] **Step 3: Run portable package suites**

```bash
swift test
```
Expected: PASS with no test failures.

- [ ] **Step 4: Run iPhone and iPad app suites**

```bash
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project Vertex.xcodeproj -scheme Vertex -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```
Expected: PASS. If the exact simulator runtime name differs on the runner, use an installed iOS 17+ iPhone and iPad destination and record the resolved destinations in the build log.

- [ ] **Step 5: Run existing model and Metal audits**

Run the repository's existing Phase-7/8 native AI model preparation/audit and Metal pixel test commands from `.github/workflows/phase-build.yml`. Do not weaken or skip license/digest/native-inference gates to make Phase 9 pass.

- [ ] **Step 6: Build unsigned arm64 Release app**

Use the same established generic-iOS unsigned release command from `phase-build.yml`, with code signing disabled and Release configuration. Expected app bundle: `Vertex2.app`, arm64, MinimumOSVersion 17.0.

- [ ] **Step 7: Package and audit the IPA**

Construct:
```text
Payload/Vertex2.app
```
Zip as:
```text
Vertex2-9.0.0-unsigned.ipa
```

Audit must prove:

```text
CFBundleDisplayName = Vertex2
CFBundleShortVersionString = 9.0.0
CFBundleVersion = 9
CFBundleIdentifier = com.woo642778.aftereffects
MinimumOSVersion = 17.0
_CodeSignature absent
embedded.mobileprovision absent
Assets.car present
metallib present
required compiled AI model bundles present
AI model manifest/license audit passes
arm64 executable present
```

- [ ] **Step 8: Generate SHA-256 and artifact inventory**

Produce:

```text
Vertex2-9.0.0-unsigned.ipa.sha256
Vertex2-9.0.0-artifact-inventory.json
AI_MODEL_MANIFEST-9.0.json
```

- [ ] **Step 9: Inspect git diff and forbidden placeholders**

Run:
```bash
git status --short
git diff --check
grep -RInE 'TODO|FIXME|fatalError\("Not implemented|placeholder|mock implementation' App Sources --exclude-dir=.build || true
```
Review every hit; test-only fixture/fake names are acceptable only inside tests. Production placeholders are release blockers.

- [ ] **Step 10: Commit release configuration**

```bash
git add Sources/VertexCore/Milestone.swift project.yml .github/workflows/phase-build.yml Tools/ai
git commit -m "release: prepare Vertex2 9.0 validation"
```

- [ ] **Step 11: Push branch, open/refresh a Draft Phase-9 PR, and wait for CI**

The PR base must be the actual Phase-8 development base used for this release lineage, not the temporary Phase-5 CI retarget used by the older PR. Do not merge Phase 8 or Phase 9 without explicit user instruction.

- [ ] **Step 12: Download only a successful CI artifact and independently inspect it**

If any required job fails, diagnose/fix/re-run and do not present an IPA as completed. After successful CI, download the artifact, independently inspect the extracted bundle against Step 7, recompute SHA-256, and only then expose the IPA to the user.

---

## Plan Self-Review

### Spec coverage

- iPad AE-style four-panel workspace: Tasks 10-12.
- iPhone compact adaptation with same engine/document: Tasks 10-12.
- Professional timeline move/trim/split/ripple/roll/slip/slide: Tasks 1-4 and 11.
- Snapping, multiselect, zoom, work area, markers: Tasks 1, 3, 4, 11.
- Keyframe timeline and graph editor: Tasks 11 and 13.
- Parenting and track matte timeline integration: Tasks 1, 4, 13.
- Ordered non-destructive effect stack: Tasks 5-6.
- Depth/Cutout/Upscale/Restore layer effects: Tasks 5, 7, 8, 12.
- Current-frame priority/cache/cancellation: Tasks 7-8.
- Effect delete/disable restores pre-effect path: Tasks 5, 6, 12, 14.
- Extract/Bake creates validated new media/layer atomically: Task 9.
- Preview/export parity and non-silent export failure: Tasks 6, 8, 14.
- Schema 4 -> 5 deterministic migration: Task 1.
- Undo/redo/autosave command route: Tasks 4, 5, 9.
- Version 9.0.0/build 9 and verified unsigned IPA: Task 15.

### Explicit scope boundaries

- Advanced retiming remains Phase 10; Phase 9 stores only `sourceOffset` and edit-compatible timing.
- Broad GPU general-effects library remains a later Effects Architecture milestone; Phase 9 adds only the typed/versioned container/evaluator needed for approved AI effects.
- Nested-composition AI effects are rejected in Phase 9 unless a real materialization path is implemented and tested during Task 6; they must not silently no-op.
- Shy/3D switches are not shown unless backing semantics already exist.
- No claim of full-resolution real-time neural inference on every supported device; current-frame responsiveness and cache reuse are the contract.

### Type consistency check

- Canonical layer effect type is `ProjectEffect`; every task uses `ProjectEffectType` and stable `VertexID` effect identity.
- Canonical effect render boundary is `CompositionEffectResolver.resolve(_:) -> PortableImage`.
- Canonical interactive edit algorithms live in `VertexTimeline`; canonical document changes remain `VertexProject` commands/mutations.
- Canonical AI single-frame identity is `AIFrameEffectKey`; app scheduler consumes `AIFrameEffectRequest` and `AIFramePriority`.
- Canonical editor playhead is `EditorWorkspaceState.playhead: RationalTime`.
- Canonical release artifact is `Vertex2-9.0.0-unsigned.ipa`.
