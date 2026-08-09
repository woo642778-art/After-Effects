# Vertex2 11.0 AE Parity + Time & Animation Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Vertex2 11.0 as an iPad-only professional compositor whose launch/home/project/composition/workspace/timeline/graph workflow closely matches current After Effects while adding a real shared Time & Animation Engine that drives both preview and export.

**Architecture:** Keep the verified 10.0 project/render/AI/3D/export foundations, extend the canonical project schema and `VertexTimeline` engine rather than creating parallel animation stores, and replace the temporary 10.0 workspace shell with a dockable AE-parity workspace bound to authoritative project commands. Native media retiming, optical flow, and pitch-preserve live behind protocol boundaries so portable timing logic remains testable on Linux/macOS Swift while Apple-native implementations are exercised in iPad/macOS CI.

**Tech Stack:** Swift 6, SwiftUI, UIKit document/file APIs, Swift Package Manager, XcodeGen, Metal/MetalKit, AVFoundation, Accelerate/vDSP where appropriate, Vision/Core Image or Metal motion-estimation backend as validated, Core ML for inherited AI effects, exact `RationalTime`, GitHub Actions.

## Global Constraints

- Target product: Vertex2 11.0.0 build 11.
- Platform: iPad-only, iPadOS 17+, landscape left/right, device family `[2]`.
- Bundle ID remains `com.woo642778.aftereffects`.
- The user-provided first `Vertex. STUDIO` image is the sole source of truth for AppIcon and Vertex Studio launch/home branding.
- Do not copy Adobe logos, Ae icons, splash artwork, or proprietary brand assets. Reproduce workflow/information architecture only with Vertex branding.
- Team Project is omitted in 11.0. Do not show a fake disabled Team Project control.
- No fake feature controls. A visible editing control must be wired to canonical project data and/or an explicit unsupported/error state.
- Preview and export must share animation/time-remap evaluation semantics.
- Authoritative timeline time remains exact `RationalTime`; floating-point seconds are adapter/presentation values only.
- Preserve 10.0 AI model integrity, 3D, persistence, Metal render, and export regression coverage.
- PR remains Draft until all final release gates and independent IPA audit pass.

---

## File Structure Map

### Canonical project/time model
- Modify `Sources/VertexProject/ProjectSchema.swift`: app version 11.0 metadata, schema migration fields, typed animatable channels, source-time remap, composition BPM/settings.
- Create `Sources/VertexProject/ProjectAnimation.swift`: `ProjectAnimatableValue`, `ProjectAnimationChannel`, `ProjectKeyframe`, temporal/spatial interpolation metadata.
- Create `Sources/VertexProject/ProjectTimeRemap.swift`: persisted source-time mapping/interpolation options.
- Modify project migration/persistence files under `Sources/VertexProjectPersistence/`: deterministic migration from legacy animation data and safe 10.x reopen.

### Portable timeline/animation engine
- Create `Sources/VertexTimeline/AnimationEvaluator.swift`: deterministic property evaluation at `RationalTime`.
- Create `Sources/VertexTimeline/GraphEditorModel.swift`: value/speed graph conversion and handle edits over the same keyframes.
- Create `Sources/VertexTimeline/TimeRemapEvaluator.swift`: source-time resolution, freeze/reverse/stretch/ramp/nested mapping.
- Create `Sources/VertexTimeline/BPMGrid.swift`: beat/subdivision/marker snapping.
- Create `Sources/VertexTimeline/GestureKeyframeReducer.swift`: timestamp normalization, smoothing, simplification, Bezier fit.
- Extend existing timeline command files in `Sources/VertexTimeline/` to mutate canonical channels with Undo-safe grouped commands.

### Native retiming/audio
- Create `Sources/VertexMediaAVFoundation/FrameInterpolation.swift`: Frame Mix + optical-flow protocol/backend.
- Create `Sources/VertexMediaAVFoundation/AudioTimeStretch.swift`: pitch-preserve/non-preserve retiming contract.
- Modify media frame resolver and composition compilation path so source-time mapping is resolved before frame fetch.
- Modify `Sources/VertexExportAVFoundation/AppleExportWriter.swift` only where required to accept synchronized audio/video output without duplicating timing logic.

### App lifecycle/workspace/UI
- Create `App/VertexStartupCoordinator.swift` and `App/VertexStartupView.swift`: explicit startup state machine and real subsystem progress.
- Create `App/VertexHomeView.swift` and `App/RecentProjectsStore.swift`: Home/New/Open/Recent lifecycle.
- Create `App/NewCompositionView.swift`: real composition settings dialog.
- Create `App/AEWorkspaceModel.swift`: dock/tab/stack/split workspace graph and persistence.
- Replace/reshape `App/AEWorkspaceLayout.swift`, `App/AEWorkspaceChrome.swift`, `App/IPadEditorWorkspaceView.swift`, and `App/VertexEditorWorkspaceView.swift` around the workspace model.
- Replace simplified `AETimelineView`/layer-row implementation and update `GraphEditorView`, `EffectControlsView`, Effects & Presets surfaces.
- Create auxiliary panels: `App/AEPreviewPanel.swift`, `App/AEInfoPanel.swift`, `App/AEAudioPanel.swift`, `App/AEAlignPanel.swift`, `App/AECharacterPanel.swift`, `App/AEParagraphPanel.swift`.
- Modify `App/EditorWorkspaceState.swift` so presentation state references canonical selection/playhead/workspace state rather than shadow copies of project values.

### Branding/release
- Store the supplied source artwork at `App/Branding/VertexStudioIconSource.png` through the GitHub blob/tree path, preserving the exact user-provided bytes.
- Modify `Tools/generate_app_assets.sh` so AppIcon and launch/home derived assets are generated from that source.
- Update `project.yml`, `Sources/VertexCore/Milestone.swift`, release/audit tooling, and Phase 11 GitHub Actions workflows.

---

### Task 1: 11.0 foundation, branding, startup, Home, and project/composition lifecycle

**Files:**
- Create: `App/VertexStartupCoordinator.swift`
- Create: `App/VertexStartupView.swift`
- Create: `App/VertexHomeView.swift`
- Create: `App/RecentProjectsStore.swift`
- Create: `App/NewCompositionView.swift`
- Modify: `App/VertexEditorWorkspaceView.swift`
- Modify: project workspace/view-model files that currently synthesize the default composition
- Modify: `project.yml`
- Modify: `Tools/generate_app_assets.sh`
- Test: `Tests/VertexAppTests/StartupHomeLifecycleTests.swift`
- Test: `Tests/VertexProjectTests/ProjectCreationTests.swift`

**Interfaces:**
- Produces `VertexStartupPhase`, `VertexStartupCoordinator`, `RecentProjectRecord`, and a real empty-project/new-composition lifecycle used by all later UI tasks.
- `VertexStartupCoordinator.start()` must terminate in `.ready`, `.recoverableFailure(VertexStartupIssue)`, or `.fatalFailure(VertexStartupIssue)`; no open-ended boolean loading flag is authoritative.

- [ ] **Step 1: Write failing lifecycle tests.**

```swift
@Test func newProjectStartsWithoutSyntheticComposition() throws {
    let project = try ProjectDocument.makeNew(name: "Untitled")
    #expect(project.compositions.isEmpty)
    #expect(project.activeCompositionID == nil)
}

@Test @MainActor func optionalAIStartupFailureStillReachesHome() async {
    let coordinator = VertexStartupCoordinator(services: .fixture(aiResult: .failure(.modelUnavailable)))
    await coordinator.start()
    #expect(coordinator.phase == .ready)
    #expect(coordinator.issues.contains(.modelUnavailable))
}
```

- [ ] **Step 2: Run focused tests and confirm they fail for the current automatic-composition/bootstrap behavior.**

Run: `swift test --filter ProjectCreationTests` and the iPad app-test target for `StartupHomeLifecycleTests`.

- [ ] **Step 3: Implement the explicit startup state machine and Home flow.**

```swift
enum VertexStartupPhase: Equatable {
    case coldStart
    case loadingServices(VertexStartupService)
    case restoringSession
    case ready
    case recoverableFailure(VertexStartupIssue)
    case fatalFailure(VertexStartupIssue)
}

@MainActor
final class VertexStartupCoordinator: ObservableObject {
    @Published private(set) var phase: VertexStartupPhase = .coldStart
    @Published private(set) var issues: [VertexStartupIssue] = []
    func start() async { /* ordered, timeout-aware subsystem initialization */ }
}
```

Home must show only Home/New Project/Open Project/Recent Projects. New Project creates an empty writable project. New Composition commits real composition dimensions, FPS, duration, start time, background, supported motion blur/renderer settings.

- [ ] **Step 4: Integrate the exact supplied Vertex Studio artwork.**

Use the uploaded `/mnt/data/KakaoTalk_Photo_2026-08-08-19-36-00.png` bytes as `App/Branding/VertexStudioIconSource.png`, generate the AppIcon set from that source, and use a screen-layout adaptation rather than stretching the icon as a splash image. Remove temporary Ae-shaped/placeholder icon identity from generated assets.

- [ ] **Step 5: Update product version/build and project metadata contract.**

Set `MARKETING_VERSION: 11.0.0`, `CURRENT_PROJECT_VERSION: 11`, and correct `ProjectDocument.currentAppVersion` after inspecting migration tests. Do not bump schema merely for marketing version unless new persisted animation fields require it.

- [ ] **Step 6: Run lifecycle/app-icon tests and commit.**

Expected: no automatic composition, real Home flow, optional startup failures do not deadlock, exact icon source is included, iPad identity remains unchanged except version/build.

Commit: `feat: add Vertex2 11 startup home and project lifecycle`

---

### Task 2: Unified canonical Animation Core and safe schema migration

**Files:**
- Create: `Sources/VertexProject/ProjectAnimation.swift`
- Create: `Sources/VertexProject/ProjectTimeRemap.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProjectPersistence/*Migration*.swift` or existing migration coordinator
- Create: `Sources/VertexTimeline/AnimationEvaluator.swift`
- Test: `Tests/VertexProjectTests/AnimationSchemaTests.swift`
- Test: `Tests/VertexProjectPersistenceTests/Phase11AnimationMigrationTests.swift`
- Test: `Tests/VertexTimelineTests/AnimationEvaluatorTests.swift`

**Interfaces:**

```swift
public enum ProjectAnimatableValue: Codable, Equatable, Sendable {
    case scalar(Double)
    case vector2(ProjectVector2)
    case vector3(ProjectVector3)
    case color(ProjectColor)
}

public struct ProjectKeyframe: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var value: ProjectAnimatableValue
    public var temporal: ProjectTemporalInterpolation
    public var spatial: ProjectSpatialInterpolation?
}

public struct ProjectAnimationChannel: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var propertyPath: String
    public var staticValue: ProjectAnimatableValue
    public var keyframes: [ProjectKeyframe]
}

public struct AnimationEvaluator: Sendable {
    public func value(of channel: ProjectAnimationChannel, at time: RationalTime) throws -> ProjectAnimatableValue
}
```

- [ ] **Step 1: Write failing tests for exact-time Linear/Hold/Bezier, velocity/influence, spatial tangents, and deterministic ordering.**

```swift
@Test func holdUsesPreviousKeyframeUntilExactBoundary() throws {
    let channel = Fixtures.holdScalar(from: 0, to: 100, start: .zero, end: RationalTime(value: 24, timescale: 24))
    #expect(try AnimationEvaluator().value(of: channel, at: RationalTime(value: 23, timescale: 24)) == .scalar(0))
    #expect(try AnimationEvaluator().value(of: channel, at: RationalTime(value: 24, timescale: 24)) == .scalar(100))
}
```

- [ ] **Step 2: Verify failures, then implement typed persisted channels and interpolation metadata without creating UI-owned keyframe storage.**

- [ ] **Step 3: Implement deterministic evaluator with exact interval lookup.**

Bezier solving must clamp malformed influence values, handle equal-time duplicates deterministically according to validation policy, and return the exact keyframe value at exact boundaries.

- [ ] **Step 4: Migrate legacy animation channels into the new representation.**

Migration must decode a copy, validate, write transactionally, and preserve the original package if migration fails. Add old-project fixtures and round-trip tests.

- [ ] **Step 5: Wire transform/effect/mask/text/3D/audio-compatible numeric properties through property paths and add registration adapters.**

Do not rewrite every renderer subsystem. Resolve the animated property into the existing canonical layer/effect structures before graph compilation.

- [ ] **Step 6: Run all project/timeline/persistence tests and commit.**

Commit: `feat: add unified exact-time animation core`

---

### Task 3: AE-parity Timeline, Graph Editor, dockable workspace, effects, and auxiliary panels

**Files:**
- Create: `App/AEWorkspaceModel.swift`
- Modify: `App/AEWorkspaceLayout.swift`
- Modify: `App/AEWorkspaceChrome.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Modify: `App/EditorWorkspaceState.swift`
- Modify: existing `App/AETimelineView.swift`, `App/AETimelineLayerRow.swift`, `App/GraphEditorView.swift`, `App/EffectControlsView.swift`
- Create: auxiliary panel files listed in the File Structure Map
- Test: `Tests/VertexAppTests/AEWorkspaceDockingTests.swift`
- Test: `Tests/VertexAppTests/AETimelineInteractionTests.swift`
- Modify: `Tests/VertexAppTests/GraphEditorInteractionTests.swift`

**Interfaces:**

```swift
struct AEWorkspaceDocument: Codable, Equatable {
    var root: AEWorkspaceNode
    var activePanelIDs: [AEPanelID]
}

enum AEWorkspaceNode: Codable, Equatable {
    case panel(AEPanelID)
    case tabs(selected: AEPanelID, panels: [AEPanelID])
    case split(axis: Axis, fraction: Double, first: Box, second: Box)
}
```

The Graph Editor consumes and mutates `ProjectAnimationChannel`; it does not own copied graph points.

- [ ] **Step 1: Write failing workspace/timeline interaction tests for dock/tab/split persistence, Stage Manager collapse, layer-property disclosure, stopwatch, add/delete/move/copy keyframes, switches/modes, parent/link, track matte, work area, markers, and Undo grouping.**

- [ ] **Step 2: Replace fixed fractional workspace layout with a persisted workspace graph.**

Keep safe width constraints, but represent panel arrangement as semantic nodes so reset/save/reopen works and narrow windows tab/collapse panels rather than vertical text wrapping.

- [ ] **Step 3: Replace the simplified timeline with a two-region AE-like timeline.**

Left side: layer number/label, AV, solo, lock, shy, 3D, motion blur, supported adjustment/mode/matte/parent columns and property tree. Right side: exact time ruler, CTI, work area, layer bars, in/out handles, markers, keyframes, snapping.

Every edit must dispatch a project/timeline command. No `@State` copy may be the authoritative value.

- [ ] **Step 4: Rebuild Graph Editor over canonical channels.**

```swift
struct GraphEditorModel {
    func valueGraph(channel: ProjectAnimationChannel, visibleRange: ClosedRange<RationalTime>) throws -> [GraphSample]
    func speedGraph(channel: ProjectAnimationChannel, visibleRange: ClosedRange<RationalTime>) throws -> [GraphSample]
    func setTemporalHandle(keyframeID: VertexID, incoming: ProjectTemporalHandle?, outgoing: ProjectTemporalHandle?) throws -> ProjectAnimationChannel
}
```

Add Value Graph/Speed Graph switching, multi-property display, velocity/influence handles, interpolation commands, zoom/pan, and exact keyframe selection shared with Timeline.

- [ ] **Step 5: Correct Effects & Presets and Effect Controls.**

Remove `AIWorkspaceView()` as the entire Effects panel. Build a registry-backed searchable hierarchy containing only actual effects. AI is one category. Apply via drag/drop or explicit action, persist the effect stack, show parameters in Effect Controls, and route animatable effect parameters through Task 2 channels.

- [ ] **Step 6: Add real Preview, Info, Audio, Align, Character, and Paragraph panels.**

Each panel must mutate/read real editor/project state. Do not add Libraries or cloud placeholders.

- [ ] **Step 7: Run iPad UI tests at wide/medium/narrow Stage Manager sizes, then commit.**

Commit: `feat: rebuild AE workspace timeline graph and panels`

---

### Task 4: Professional time remap, frame interpolation, gesture recording, BPM, and audio pitch preserve

**Files:**
- Create: `Sources/VertexTimeline/TimeRemapEvaluator.swift`
- Create: `Sources/VertexTimeline/BPMGrid.swift`
- Create: `Sources/VertexTimeline/GestureKeyframeReducer.swift`
- Create: `Sources/VertexMediaAVFoundation/FrameInterpolation.swift`
- Create: `Sources/VertexMediaAVFoundation/AudioTimeStretch.swift`
- Modify: media frame resolver/composition resolver files
- Test: `Tests/VertexTimelineTests/TimeRemapEvaluatorTests.swift`
- Test: `Tests/VertexTimelineTests/BPMGridTests.swift`
- Test: `Tests/VertexTimelineTests/GestureKeyframeReducerTests.swift`
- Test: `Tests/VertexMediaAVFoundationTests/FrameInterpolationTests.swift`
- Test: `Tests/VertexMediaAVFoundationTests/AudioTimeStretchTests.swift`

**Interfaces:**

```swift
public struct TimeRemapEvaluator: Sendable {
    public func sourceTime(mapping: ProjectTimeRemap, compositionTime: RationalTime) throws -> RationalTime
}

public enum FrameInterpolationMode: Codable, Sendable { case nearest, frameMix, opticalFlow }

public protocol FrameInterpolator: Sendable {
    func frame(at sourceTime: RationalTime, request: FrameInterpolationRequest) async throws -> ResolvedVideoFrame
}

public protocol AudioTimeStretcher: Sendable {
    func render(_ request: AudioTimeStretchRequest) async throws -> AudioTimeStretchResult
}
```

- [ ] **Step 1: Write failing exact-time tests for stretch, reverse, freeze, animated source-time ramps, nested mapping, 23.976/29.97/59.94 rates, and long-duration drift.**

- [ ] **Step 2: Implement `ProjectTimeRemap` and portable `TimeRemapEvaluator` using `RationalTime` only.**

Reverse and Freeze should be utilities that construct/edit the same source-time channel, not separate playback-only hacks.

- [ ] **Step 3: Add Frame Mix and a real optical-flow backend with explicit failure policy.**

Define a typed error such as `FrameInterpolationError.motionEstimationFailed`. If optical flow fails, either use an explicitly configured fallback (`frameMix`) or surface the error; never silently produce a corrupted intermediate frame.

- [ ] **Step 4: Add pitch-preserve/non-preserve audio time stretch and synchronization tests.**

Use a single source-time mapping to derive both video presentation and audio stretch schedule. Verify sample/end timestamps remain within the exact frame/audio tolerance declared by tests.

- [ ] **Step 5: Add BPM grid/subdivision snapping and gesture recording reduction.**

Gesture samples become ordinary canonical Position/Rotation/Scale keyframes after smoothing/simplification; test that a smooth one-second gesture does not produce an unbounded keyframe count.

- [ ] **Step 6: Expose the functionality in Timeline/Graph/Viewer controls and commit.**

Commit: `feat: add professional retiming optical flow and motion recording`

---

### Task 5: Preview/export parity, recovery semantics, and end-to-end integration

**Files:**
- Modify: composition graph compiler/evaluation adapter under `Sources/VertexComposition/`
- Modify: `App/CompositionExportController.swift`
- Modify: `Sources/VertexExportAVFoundation/AppleExportWriter.swift`
- Create/modify: project autosave/recovery coordinator in App/Project persistence layer
- Test: `Tests/VertexCompositionTests/AnimatedCompositionParityTests.swift`
- Test: `Tests/VertexExportAVFoundationTests/AnimatedExportParityTests.swift`
- Test: `Tests/VertexAppTests/ProjectRecoveryTests.swift`

**Interfaces:**

```swift
struct ResolvedProjectStateEvaluator {
    func resolve(project: ProjectDocument, compositionID: VertexID, at time: RationalTime) throws -> ResolvedCompositionState
}
```

Both preview and export invoke the same resolver before `CompositionGraphCompiler` consumes the state.

- [ ] **Step 1: Write failing parity tests where eased Position, animated effect parameter, Time Remap, reverse/freeze, and nested composition produce known frame signatures in both preview-purpose and export-purpose compilation.**

- [ ] **Step 2: Insert one shared resolved-state evaluation stage into preview and export.**

Do not create a second export animation evaluator. Existing AI effect resolver and Metal render path remain downstream.

- [ ] **Step 3: Add synchronized audio export for retimed media.**

The 10.0 hardcoded `includeAudio: false` is removed only after a real audio source path exists. If audio cannot be resolved for a job, return a typed error instead of producing falsely advertised audio.

- [ ] **Step 4: Implement autosave/recovery snapshots and explicit project-open terminal states.**

Recovery options are Recover Project/Open Original/Discard Recovery when a valid snapshot exists. Corrupt recovery data must not prevent opening the original project.

- [ ] **Step 5: Run complete package + iPad simulator regression and commit.**

Commit: `feat: unify animated preview export and recovery`

---

### Task 6: Phase 11 milestone, CI qualification, independent IPA audit, and final artifact

**Files:**
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `Tests/VertexCoreTests/MilestoneTests.swift`
- Modify: `Tests/VertexCoreTests/CoreArchitectureTests.swift`
- Create: `.github/workflows/phase11-ae-time-engine.yml`
- Create: `.github/workflows/phase11-release-ipa.yml`
- Modify: `Tools/release/audit_vertex2_ipa.py`
- Modify: `project.yml`

**Interfaces:**
- Final artifact must be exactly `Vertex2-11.0.0-unsigned.ipa` and must pass strict independent audit before completion is claimed.

- [ ] **Step 1: Update Milestone 11 and architecture tests to describe only functionality proven by the implementation.**

- [ ] **Step 2: Add Phase 11 CI gates.**

Required sequence: `git diff --check`; portable Swift tests; inherited pinned AI download/hash/compile/inference audit; native animation/media/optical-flow/audio tests; XcodeGen; iPad Simulator app tests; unsigned iOS 17 arm64 Release build; bundle identity/orientation/device-family/icon/model/Metal inspection; IPA package; independent IPA audit; SHA-256.

- [ ] **Step 3: Harden `audit_vertex2_ipa.py` for 11.0.**

Verify marketing/build version, iPad family, landscape orientations, arm64 thin binary, unsigned state, Metal library, exact compiled AI models/notices, non-empty Vertex Studio icon resources, and reject stale 10.0/placeholder branding evidence.

- [ ] **Step 4: Run CI on the final candidate and inspect the first actual failure rather than guessing.**

For every failure: retrieve job steps/logs, make the smallest evidence-based fix, rerun, and repeat until all required workflows are green on the same commit.

- [ ] **Step 5: Download and independently inspect the final artifact.**

Unzip the Actions artifact locally, calculate SHA-256 of the IPA, unpack `Payload/Vertex2.app`, inspect `Info.plist`, executable architecture/signing, icon/resources, AI models/notices, and ensure no `_CodeSignature` or `embedded.mobileprovision` exists.

- [ ] **Step 6: Update Draft PR #18 with verified commit/run/artifact IDs, SHA-256, size, feature truth table, and known limitations.**

Keep PR Draft and unmerged unless the user explicitly approves integration.

Commit: `ci: qualify Vertex2 11 release`

---

## Plan Self-Review Checklist

- Spec coverage: Startup/Home/project lifecycle, New Composition, app icon, workspace/panels, AE Timeline, Graph Editor, unified animation core, gesture recording, Time Remap, Frame Mix/Optical Flow, Pitch Preserve, BPM, preview/export parity, recovery, migrations, tests, and IPA qualification are mapped to Tasks 1-6.
- No future 12-28 roadmap subsystem is represented as a completed 11.0 feature.
- No Team Project or Libraries/cloud placeholder is planned.
- Canonical animation ownership is in `VertexProject`; evaluation/editing logic is in `VertexTimeline`; Graph/Timeline/UI do not own duplicate animation data.
- Exact `RationalTime` remains authoritative end-to-end.
- Native optical flow/audio are isolated behind testable protocol boundaries.
- The supplied Vertex Studio source image is explicitly preserved as the icon source of truth.
- Every major task ends in focused tests and a commit; final completion requires same-commit green CI plus independent IPA inspection.
