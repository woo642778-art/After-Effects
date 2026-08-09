# Vertex2 11.0 AE Parity + Time & Animation Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Vertex2 11.0.0 as an iPad-only professional compositor whose startup, Home, project/composition lifecycle, workspace, Timeline, Graph Editor, effects workflow, and auxiliary panels closely follow current After Effects semantics, while upgrading the existing exact-time animation foundation into a production Time & Animation Engine that drives preview and export identically.

**Architecture:** Preserve the verified 10.0 project, persistence, animation-channel, timeline-editing, composition-compiler, Metal render, AI, 3D, and export foundations. Extend the existing `ProjectAnimationChannel` model rather than introducing a second keyframe store; keep advanced timing math deterministic over `RationalTime`; keep native frame interpolation and audio time-stretch behind Apple-platform adapters; and replace the temporary 10.0 panel shell with a semantic dock/tab/split workspace whose controls dispatch canonical project commands.

**Tech Stack:** Swift 6, SwiftUI, UIKit document/file APIs, Swift Package Manager, XcodeGen, Metal/MetalKit, AVFoundation, Vision + Metal for optical-flow synthesis, AVAudioEngine/AVAudioUnitTimePitch/AVAudioUnitVarispeed for audio retiming, Core ML for inherited AI effects, exact `RationalTime`, GitHub Actions.

## Global Constraints

- Target product: Vertex2 11.0.0 build 11.
- Platform: iPad-only, iPadOS 17+, landscape left/right, device family `[2]`.
- Bundle ID remains `com.woo642778.aftereffects`.
- The user-provided first `Vertex. STUDIO` image is the sole AppIcon source. Approved source metadata: 2000×2000 RGBA PNG, 452,806 bytes, SHA-256 `4f0dc1287a50e5c69e1882f6540820de7e4681531e75c40fa45b02af8fec6a8a`.
- Do not copy Adobe logos, Ae icons, Adobe splash artwork, or proprietary brand assets. Reproduce workflow/information architecture with Vertex branding.
- Team Project is omitted in 11.0. No fake disabled Team Project control.
- Libraries/cloud collaboration is omitted until real infrastructure exists.
- No fake feature controls. Visible editing controls must mutate/read canonical project state or clearly represent an error/unsupported state.
- Authoritative time remains `RationalTime`; floating seconds are presentation/adaptor values only.
- Preview and export must continue through the same `CompositionGraphCompiler` and the same animation/time-remap semantics.
- Preserve 10.0 AI model integrity, 3D, persistence, composition, Metal, export, iPad-only, and unsigned-release regression checks.
- Preserve the existing Telegram promotion feature; it may be rescheduled so it does not interrupt the startup state machine, but it must not be silently deleted.
- PR remains Draft until final release gates and independent IPA audit pass.

## Existing Foundation To Reuse, Not Rebuild

- `Sources/VertexProject/ProjectAnimation.swift` already owns `ProjectAnimatableValue`, `ProjectKeyframe`, `ProjectAnimationChannel`, exact Linear/Hold/Cubic-Bezier evaluation, mask/effect property addresses, and validation.
- `Tests/VertexProjectTests/ProjectAnimationTests.swift` already covers exact scalar interpolation, Hold, Bezier, validation, and animated mask paths.
- `Sources/VertexTimeline/TimelineEngine.swift` already implements move, trim, split, ripple, roll, slip, slide, marker shifting, and animation-channel partitioning.
- `App/AETimelineView.swift` and `App/AETimelineLayerRow.swift` already use exact-time interaction and basic layer controls; 11.0 replaces the simplified visual model while retaining working edit semantics.
- `App/GraphEditorView.swift` already edits canonical `ProjectAnimationChannel` data and has Value/Speed mode foundations.
- `Sources/VertexComposition/LayerAnimationEvaluator.swift` and `EffectAnimationEvaluator.swift` already evaluate canonical animation data inside the renderer path.
- `Sources/VertexComposition/CompositionGraphCompiler.swift` already calls those evaluators, so 11.0 must extend this path instead of adding a preview-only evaluator.
- `App/CompositionPreviewController.swift` and `App/CompositionExportController.swift` already share the compiler + Metal renderer pattern.
- `App/ProjectSessionActor.swift`, `ProjectWorkspaceViewModel.swift`, and `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift` already provide atomic persistence, autosave/pending recovery, Undo/Redo, and project-open verification.

---

### Task 1: Phase 11 product foundation, exact Vertex Studio branding, startup/Home, and AE-like project/composition lifecycle

**Files:**
- Modify: `App/VertexApp.swift`
- Modify: `App/AppStartupState.swift`
- Modify: `App/Vertex2SplashView.swift`
- Modify: `App/RootView.swift`
- Modify: `App/VertexEditorWorkspaceView.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectSessionActor.swift`
- Create: `App/VertexStartupCoordinator.swift`
- Create: `App/VertexHomeView.swift`
- Create: `App/RecentProjectsStore.swift`
- Create: `App/NewCompositionView.swift`
- Modify: `App/Resources/AppIconSource.base64`
- Modify: `Tools/generate_app_assets.sh`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/ProjectComposition.swift`
- Modify: `project.yml`
- Test: `Tests/VertexAppTests/StartupHomeLifecycleTests.swift`
- Test: `Tests/VertexAppTests/NewCompositionInteractionTests.swift`
- Modify: `Tests/VertexProjectTests/ProjectSchemaTests.swift`

**Interfaces:**

```swift
enum VertexStartupService: String, Sendable {
    case projectPersistence
    case renderer
    case effects
    case aiModels
    case workspace
}

enum VertexStartupPhase: Equatable, Sendable {
    case coldStart
    case loading(VertexStartupService)
    case restoringSession
    case ready
    case fatal(String)
}

struct VertexStartupServices: Sendable {
    var prepareProjectPersistence: @Sendable () async throws -> Void
    var prepareRenderer: @Sendable () async throws -> Void
    var prepareEffects: @Sendable () async throws -> Void
    var prepareAIModels: @Sendable () async throws -> Void
    var restoreWorkspace: @Sendable () async throws -> Void
}
```

`VertexStartupCoordinator.start()` must always reach `.ready` or `.fatal`. Optional failures are accumulated as warnings and cannot leave the app in a permanent loading state.

- [ ] **Step 1: Write failing startup/project tests before changing behavior.**

```swift
@Test func newProjectStartsEmpty() throws {
    let project = try ProjectDocument.makeNew(name: "Untitled Project")
    #expect(project.compositionRegistry.isEmpty)
    #expect(project.activeCompositionID == nil)
}

@Test @MainActor func optionalAIStartupFailureDoesNotBlockReady() async {
    let services = VertexStartupServices.fixture(aiFailure: TestFailure())
    let coordinator = VertexStartupCoordinator(services: services)
    await coordinator.start()
    #expect(coordinator.phase == .ready)
    #expect(coordinator.warnings.count == 1)
}
```

- [ ] **Step 2: Run focused tests and verify the empty-project test fails because `ProjectDocument.makeNew` currently creates `Main Composition`.**

Run: `swift test --filter ProjectSchemaTests`

- [ ] **Step 3: Implement an explicit real startup coordinator.**

```swift
@MainActor
final class VertexStartupCoordinator: ObservableObject {
    @Published private(set) var phase: VertexStartupPhase = .coldStart
    @Published private(set) var warnings: [String] = []
    private let services: VertexStartupServices

    init(services: VertexStartupServices) { self.services = services }

    func start() async {
        do {
            phase = .loading(.projectPersistence)
            try await services.prepareProjectPersistence()
            phase = .loading(.renderer)
            try await services.prepareRenderer()
            phase = .loading(.effects)
            try await services.prepareEffects()
        } catch {
            phase = .fatal(error.localizedDescription)
            return
        }

        phase = .loading(.aiModels)
        do { try await services.prepareAIModels() }
        catch { warnings.append(error.localizedDescription) }

        phase = .restoringSession
        do { try await services.restoreWorkspace() }
        catch { warnings.append(error.localizedDescription) }

        phase = .ready
    }
}
```

Wire `VertexApp`/`Vertex2SplashView` to real service phases instead of an 850 ms decorative delay. The splash should follow AE-like professional startup pacing while showing only Vertex Studio identity and real subsystem status.

- [ ] **Step 4: Replace direct editor bootstrap with Home → New/Open Project → empty project → New Composition.**

Change `ProjectDocument.makeNew` to create zero compositions and nil active selection. Update `ProjectSessionActor.create`, `ProjectWorkspaceViewModel.createProject`, and validation to accept an empty new project. Existing older projects containing a default composition remain valid.

- [ ] **Step 5: Implement `VertexHomeView` and `RecentProjectsStore`.**

Persist recent records containing stable project ID, display name, local package URL/bookmark, last-opened date, and thumbnail path when available. Missing entries expose `Project Not Found` and removable recent records rather than blocking launch.

- [ ] **Step 6: Implement AE-like New Composition as real persisted composition settings.**

Extend `ProjectComposition` with backward-decoding defaults for:

```swift
public var displayStartTime: RationalTime
public var bpm: Double?
public var motionBlurShutterAngle: Double
public var motionBlurShutterPhase: Double
public var rendererMode: ProjectCompositionRendererMode
```

`NewCompositionView` edits Name, preset, width/height, pixel aspect when supported, frame rate, resolution metadata, start time/frame, duration, background, supported motion-blur settings, and renderer choice. Creating the composition dispatches a real `.insertComposition` command through `ProjectWorkspaceViewModel`.

- [ ] **Step 7: Replace the current icon source with the exact approved attachment bytes.**

Decode `App/Resources/AppIconSource.base64` in the asset generator and assert SHA-256 equals `4f0dc1287a50e5c69e1882f6540820de7e4681531e75c40fa45b02af8fec6a8a` before resizing. Change the temporary decoded source extension to `.png`. Generated AppIcon images and `LaunchLogo` derive only from that verified source.

- [ ] **Step 8: Update versioning without hiding schema changes.**

Set `MARKETING_VERSION: 11.0.0`, `CURRENT_PROJECT_VERSION: 11`, `ProjectDocument.currentAppVersion = "11.0.0"`. Bump `currentSchemaVersion` only once the persisted Task 2/4 fields are finalized, then add backward decode/migration tests before changing the reader floor.

- [ ] **Step 9: Run lifecycle, project, asset-generation, and iPad app tests; commit.**

Commit: `feat: add Vertex2 11 startup home project lifecycle and branding`

---

### Task 2: Extend the existing animation channels into the full advanced Animation Core

**Files:**
- Modify: `Sources/VertexProject/ProjectAnimation.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexComposition/LayerAnimationEvaluator.swift`
- Modify: `Sources/VertexComposition/EffectAnimationEvaluator.swift`
- Modify: `Sources/VertexTimeline/TimelineEngine.swift`
- Create: `Sources/VertexTimeline/AnimationEditEngine.swift`
- Create: `Sources/VertexTimeline/GraphCurveMath.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `Tests/VertexProjectTests/ProjectAnimationTests.swift`
- Create: `Tests/VertexTimelineTests/AnimationEditEngineTests.swift`
- Create: `Tests/VertexTimelineTests/GraphCurveMathTests.swift`
- Create: `Tests/VertexCompositionTests/AdvancedAnimationEvaluationTests.swift`

**Interfaces:**

Do not redefine `ProjectAnimatableValue`, `ProjectKeyframe`, or `ProjectAnimationChannel`. Extend them compatibly.

```swift
public enum ProjectSpatialInterpolationMode: String, Codable, Sendable {
    case linear
    case bezier
    case autoBezier
    case continuousBezier
}

public struct ProjectSpatialTangent: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double?
}

public struct ProjectKeyframeVelocity: Codable, Equatable, Sendable {
    public var valuePerSecond: Double
    public var influence: Double       // 0...100
}
```

Add backward-compatible optional fields to `ProjectKeyframe`: incoming/outgoing velocity, spatial incoming/outgoing tangent, spatial mode, and roving flag. Existing projects decode these as nil/defaults.

- [ ] **Step 1: Add failing tests for advanced temporal semantics before modifying the model.**

Cover Easy Ease, Ease In, Ease Out, explicit influence/velocity, Auto/Continuous Bezier metadata, roving-key validity, exact boundaries, and 23.976/29.97/59.94 frame-rate cases.

- [ ] **Step 2: Extend the existing canonical types and decoding defaults.**

Keep existing `.hold`, `.linear`, `.cubicBezier` encoding stable. Easy Ease commands map to cubic Bezier + velocity/influence metadata rather than creating a second animation type.

- [ ] **Step 3: Implement `AnimationEditEngine` as immutable canonical channel transformations.**

```swift
public struct AnimationEditEngine: Sendable {
    public func addKeyframe(_ keyframe: ProjectKeyframe, to channel: ProjectAnimationChannel) throws -> ProjectAnimationChannel
    public func removeKeyframes(ids: Set<VertexID>, from channel: ProjectAnimationChannel) throws -> ProjectAnimationChannel
    public func moveKeyframes(ids: Set<VertexID>, by delta: RationalTime, in channel: ProjectAnimationChannel) throws -> ProjectAnimationChannel
    public func scaleKeyframeTimes(ids: Set<VertexID>, anchor: RationalTime, factor: Double, in channel: ProjectAnimationChannel) throws -> ProjectAnimationChannel
    public func applyEase(_ ease: ProjectKeyframeEaseCommand, keyframeIDs: Set<VertexID>, in channel: ProjectAnimationChannel) throws -> ProjectAnimationChannel
}
```

All outputs call canonical validation and keep keyframes strictly ordered. Grouped UI edits become one `ProjectCommandPayload` so Undo/Redo is atomic.

- [ ] **Step 4: Implement graph/speed math over the same channel evaluator.**

`GraphCurveMath.value(...)` samples `channel.evaluatedValue(at:)`; `speed(...)` evaluates deterministic derivatives using exact neighboring times and the same Bezier control metadata. Graph Editor never owns independent curve points.

- [ ] **Step 5: Extend property coverage.**

Add canonical property addresses/values needed by 11.0 for combined 2D position/anchor/scale, 3D vector properties where the existing camera/light model exposes them, color-capable effect parameters, and supported audio/time properties. Define conflict validation so a combined Position channel and separated X/Y Position channels cannot both be active simultaneously.

- [ ] **Step 6: Extend `LayerAnimationEvaluator` and `EffectAnimationEvaluator` instead of adding another render evaluator.**

The render path remains `ProjectAnimationChannel.evaluatedValue` → layer/effect state → `CompositionGraphCompiler`, which preserves preview/export parity.

- [ ] **Step 7: Extend `TimelineEngine` and `ProjectWorkspaceViewModel` with canonical keyframe commands.**

Moving/splitting a layer must continue moving/partitioning its animation channels. New keyframe edits reuse the same session command/Undo stack.

- [ ] **Step 8: Run Project/Timeline/Composition tests; commit.**

Commit: `feat: extend canonical animation engine with AE keyframe semantics`

---

### Task 3: Replace the temporary 10.0 shell with AE-parity dockable workspace, Timeline, Graph Editor, Effects, and auxiliary panels

**Files:**
- Create: `App/AEWorkspaceModel.swift`
- Modify: `App/AEWorkspaceLayout.swift`
- Modify: `App/AEWorkspaceChrome.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Modify: `App/VertexEditorWorkspaceView.swift`
- Modify: `App/EditorWorkspaceState.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `App/AETimelineView.swift`
- Modify: `App/AETimelineLayerRow.swift`
- Modify: `App/GraphEditorView.swift`
- Modify: `App/EffectControlsView.swift`
- Create: `App/EffectsAndPresetsView.swift`
- Create: `App/AEPreviewPanel.swift`
- Create: `App/AEInfoPanel.swift`
- Create: `App/AEAudioPanel.swift`
- Create: `App/AEAlignPanel.swift`
- Create: `App/AECharacterPanel.swift`
- Create: `App/AEParagraphPanel.swift`
- Test: `Tests/VertexAppTests/AEWorkspaceDockingTests.swift`
- Test: `Tests/VertexAppTests/AETimelineInteractionTests.swift`
- Modify: `Tests/VertexAppTests/AEWorkspaceLayoutTests.swift`
- Modify: `Tests/VertexAppTests/GraphEditorInteractionTests.swift`

**Interfaces:**

```swift
enum AEPanelID: String, Codable, CaseIterable, Sendable {
    case project, effectsAndPresets, composition, effectControls
    case timeline, graphEditor, preview, info, audio, align, character, paragraph
}

indirect enum AEWorkspaceNode: Codable, Equatable, Sendable {
    case panel(AEPanelID)
    case tabs(selected: AEPanelID, panels: [AEPanelID])
    case split(axis: AEWorkspaceAxis, fraction: Double, first: AEWorkspaceNode, second: AEWorkspaceNode)
}

struct AEWorkspaceDocument: Codable, Equatable, Sendable {
    var root: AEWorkspaceNode
    var floatingOrOverlayPanels: [AEPanelID]
}
```

- [ ] **Step 1: Write failing layout/persistence tests for tab/split/dock/reset and narrow Stage Manager widths.**

A supported narrow layout must tab/collapse lower-priority panels rather than turn `Open / Import / Export` labels vertical.

- [ ] **Step 2: Replace fraction-only `AEWorkspaceLayoutPolicy` with a semantic workspace graph.**

Keep deterministic minimum sizes, save/reset workspace, restore after relaunch, and preserve top-level Composition/3D/Export modes. 3D and Export remain real 10.0 workspaces, not discarded during the UI rebuild.

- [ ] **Step 3: Rebuild Project and Effects & Presets panels.**

`ProjectWorkspaceView` becomes an AE-like project tree/search/import surface instead of a persistence diagnostics card. Persistence actions move to menus/commands. `EffectsAndPresetsView` uses an actual registry of currently implemented effects; `AIWorkspaceView()` no longer occupies the whole Effects panel. Depth Map, Cutout, Upscale, and Restore appear under AI.

- [ ] **Step 4: Rebuild Effect Controls around Transform + ordered effects.**

Remove AI-only copy such as “Add an AI effect”. Transform/effect parameter changes mutate project data. Stopwatch/keyframe controls call Task 2 channel commands. Effect drag/drop/double-click applies a real `ProjectEffect` to the selected eligible layer.

- [ ] **Step 5: Replace the Timeline slider presentation with an AE-like two-region Timeline.**

Reuse `AETimelineInteractionModel` and `TimelineEngine`. Left region contains layer number/label, AV, Solo, Lock, Shy, 3D, Motion Blur, supported Adjustment, Modes, Track Matte, Parent & Link, and disclosure tree. Right region contains exact ruler, CTI, work area, bars, in/out handles, markers, keyframes, snapping, and Graph Editor toggle. Remove phase-specific helper naming such as `phase9SetLayerEnabled` from the UI path.

- [ ] **Step 6: Upgrade `GraphEditorView` in place.**

Keep canonical `ProjectAnimationChannel` inputs. Add Value/Speed Graph, multiple selected properties, pan/zoom, Bezier handle editing, velocity/influence readouts, Easy Ease commands, roving state, and shared Timeline keyframe selection.

- [ ] **Step 7: Add real auxiliary panels.**

Preview controls playback/step/loop/audio preview. Info exposes pointer/pixel/item metadata. Audio shows supported levels/properties. Align performs actual layer alignment/distribution commands. Character/Paragraph edit actual text-layer properties only where text layers are supported; otherwise the panels are hidden rather than fake.

- [ ] **Step 8: Run wide/medium/narrow iPad Simulator tests; commit.**

Commit: `feat: rebuild Vertex2 workspace timeline graph and panels for AE parity`

---

### Task 4: Professional source-time remapping, Frame Mix, optical flow, gesture recording, BPM, and pitch-preserved audio

**Files:**
- Create: `Sources/VertexProject/ProjectTimeRemap.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectComposition.swift`
- Create: `Sources/VertexTimeline/TimeRemapEvaluator.swift`
- Create: `Sources/VertexTimeline/BPMGrid.swift`
- Create: `Sources/VertexTimeline/GestureKeyframeReducer.swift`
- Modify: `Sources/VertexComposition/CompositionTypes.swift`
- Modify: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Modify: `App/CompositionMediaFrameResolver.swift`
- Create: `Sources/VertexMediaAVFoundation/FrameInterpolation.swift`
- Create: `Sources/VertexMediaAVFoundation/AudioTimeStretch.swift`
- Test: `Tests/VertexTimelineTests/TimeRemapEvaluatorTests.swift`
- Test: `Tests/VertexTimelineTests/BPMGridTests.swift`
- Test: `Tests/VertexTimelineTests/GestureKeyframeReducerTests.swift`
- Test: `Tests/VertexMediaAVFoundationTests/FrameInterpolationTests.swift`
- Test: `Tests/VertexMediaAVFoundationTests/AudioTimeStretchTests.swift`
- Modify: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`

**Interfaces:**

```swift
public enum ProjectFrameInterpolationMode: String, Codable, Sendable {
    case nearest
    case frameMix
    case opticalFlow
}

public struct ProjectTimeRemap: Codable, Equatable, Sendable {
    public var keyframes: [ProjectTimeRemapKeyframe]
    public var interpolationMode: ProjectFrameInterpolationMode
    public var preserveAudioPitch: Bool
}

public struct TimeRemapEvaluator: Sendable {
    public func sourceTime(mapping: ProjectTimeRemap, compositionTime: RationalTime) throws -> RationalTime
}
```

`ProjectLayer` receives optional `timeRemap` and backward-decodes it as nil.

- [ ] **Step 1: Write failing exact-time tests for stretch, Reverse, Freeze, variable ramp, nested mapping, and long-duration 23.976/29.97/59.94 cases.**

- [ ] **Step 2: Implement `ProjectTimeRemap` and `TimeRemapEvaluator`.**

Reverse/Freeze/Time Stretch utilities create or edit the same source-time map; they are not playback-only flags. Exact keyframe times remain `RationalTime`; source-time evaluation returns deterministic `RationalTime` with explicit rounding policy at media-frame resolution.

- [ ] **Step 3: Change `CompositionGraphCompiler` source-time calculation to use the map.**

Current media/nested source time is `compositionTime - startTime + sourceStartTime + sourceOffset`. When `layer.timeRemap` exists, pass the local layer time through `TimeRemapEvaluator`; otherwise preserve the current formula exactly. Apply the same rule to nested compositions and track-matte source layers.

- [ ] **Step 4: Extend `CompositionTypes` frame-resolution request with interpolation mode.**

```swift
public struct CompositionFrameRequest: Sendable {
    public var mediaID: VertexID
    public var exactSourceTime: RationalTime
    public var targetSize: VertexSize
    public var interpolationMode: ProjectFrameInterpolationMode
}
```

Update `CompositionFrameResolver` and cache keys accordingly so preview/export resolve the same interpolation policy.

- [ ] **Step 5: Implement real Frame Mix and optical-flow interpolation in `FrameInterpolation.swift`.**

Frame Mix decodes bracketing frames and blends at the deterministic fractional source position. Optical Flow decodes the same bracketing frames, generates a Vision optical-flow field, and performs bidirectional Metal warping/blending into the intermediate frame. Define `FrameInterpolationError.motionEstimationFailed`; only an explicitly selected fallback may downgrade to Frame Mix. Silent corrupted output is forbidden.

- [ ] **Step 6: Implement pitch-preserved and varispeed audio retiming.**

Use `AVAudioUnitTimePitch` for preserve-pitch time stretch and `AVAudioUnitVarispeed` for pitch-following playback. `AudioTimeStretchRequest` is derived from the same `ProjectTimeRemap` used for video. Tests compare output duration/timestamps against the mapped video duration.

- [ ] **Step 7: Implement BPM grid and gesture recording.**

`BPMGrid` produces exact beat/subdivision `RationalTime`s for snapping/marker generation. `GestureKeyframeReducer` receives timestamped touch/Pencil Position/Rotation/Scale samples, removes noise with deterministic smoothing, simplifies using an explicit tolerance, fits spatial tangents, and returns ordinary `ProjectKeyframe`s. A one-second smooth gesture must not create unbounded keyframes.

- [ ] **Step 8: Expose Time Remap, frame interpolation, pitch preserve, BPM, and recording in Timeline/Graph/Viewer; run tests; commit.**

Commit: `feat: add professional retiming optical flow audio and motion recording`

---

### Task 5: End-to-end Preview/Export parity, audio export, recovery states, and bug regression

**Files:**
- Modify: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Modify: `Sources/VertexComposition/LayerAnimationEvaluator.swift`
- Modify: `Sources/VertexComposition/EffectAnimationEvaluator.swift`
- Modify: `App/CompositionPreviewController.swift`
- Modify: `App/CompositionExportController.swift`
- Modify: `Sources/VertexExport/ExportModels.swift`
- Modify: `Sources/VertexExportAVFoundation/AppleExportWriter.swift`
- Modify: `App/ProjectSessionActor.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/ProjectWorkspaceView.swift`
- Modify: `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift`
- Test: `Tests/VertexCompositionTests/AnimatedCompositionParityTests.swift`
- Test: `Tests/VertexExportAVFoundationTests/AnimatedExportParityTests.swift`
- Test: `Tests/VertexAppTests/ProjectRecoveryTests.swift`
- Modify: `Tests/VertexExportAVFoundationTests/AppleExportWriterTests.swift`

- [ ] **Step 1: Add parity fixtures before integration.**

Build one deterministic project containing eased Position, animated opacity/effect parameter, masks, nested composition, Time Remap, Frame Mix/Optical Flow mode, and audio retiming. Assert interactive-preview and export-purpose compiler graphs resolve the same canonical state at the same `RationalTime`.

- [ ] **Step 2: Keep all advanced animation inside the existing compiler/evaluator path.**

Do not create a preview-only animation evaluator. `CompositionPreviewController` and `CompositionExportController` continue to construct `CompositionRenderRequest`; `CompositionGraphCompiler` evaluates all Task 2/4 semantics.

- [ ] **Step 3: Replace `includeAudio: false` only after a real audio source provider exists.**

Extend `ExportJob`/`AppleExportWriter` with an optional synchronized audio provider. MOV/MP4 jobs with requested audio must mux rendered video frames and retimed PCM/compressed audio on the same exact schedule. If audio cannot be resolved, fail with a typed error rather than silently emitting a video-only file.

- [ ] **Step 4: Upgrade project-open/recovery UI around existing atomic persistence.**

Keep `VertexProjectPackageStore` pending-snapshot safety. `ProjectWorkspaceViewModel` exposes explicit `opening → validating → migrating → resolvingMedia → ready/failed` presentation states, and recovery UI maps to existing Apply Pending/Discard Pending plus Open Original when appropriate. No generic infinite `running` state may survive after an operation Task terminates.

- [ ] **Step 5: Add regression tests for reported 10.0 UI failures.**

Cover narrow panel text wrapping, simplified Timeline slider removal, Effects panel AI takeover removal, Home flow, saved keyframes after reopen, grouped Undo/Redo, Graph curve vs evaluated motion, Time Remap one-frame boundaries, missing media, corrupt recent project, optional AI-model failure, and launch termination.

- [ ] **Step 6: Run full Swift package + iPad Simulator + native media regression; commit.**

Commit: `feat: unify Vertex2 11 preview export audio and recovery`

---

### Task 6: Phase 11 milestone, CI qualification, strict IPA audit, and final artifact

**Files:**
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `Tests/VertexCoreTests/MilestoneTests.swift`
- Modify: `Tests/VertexCoreTests/CoreArchitectureTests.swift`
- Create: `.github/workflows/phase11-ae-time-engine.yml`
- Create: `.github/workflows/phase11-release-ipa.yml`
- Modify: `Tools/release/audit_vertex2_ipa.py`
- Modify: `project.yml`

**Final artifact:** `Vertex2-11.0.0-unsigned.ipa`

- [ ] **Step 1: Update Milestone 11 only with functionality proven by Tasks 1-5.**

Do not claim 12-28 roadmap features. Keep inherited source-adoption/license provenance.

- [ ] **Step 2: Add Phase 11 CI gates.**

Required order: `git diff --check`; portable Swift tests; pinned AI fetch/hash/license audit; real compiled-model inference; native animation/media/optical-flow/audio tests; XcodeGen; iPad Simulator app tests; unsigned iOS 17 arm64 Release build; bundle inspection; app-icon source hash/generated-resource inspection; strict IPA audit; SHA-256.

- [ ] **Step 3: Harden `audit_vertex2_ipa.py`.**

Verify `Vertex2`, `com.woo642778.aftereffects`, `11.0.0 (11)`, iPad `[2]`, landscape left/right, iPadOS 17 minimum, thin arm64, unsigned state, no `_CodeSignature`, no `embedded.mobileprovision`, Metal library, exact three compiled AI models/notices, non-empty AppIcon resources, and release evidence that decoded icon source SHA-256 is `4f0dc1287a50e5c69e1882f6540820de7e4681531e75c40fa45b02af8fec6a8a`.

- [ ] **Step 4: Run the final candidate workflows and debug only from actual failing logs.**

For every failure: fetch job steps/logs, identify the first real failing assertion/compiler/runtime error, make the smallest evidence-based fix, rerun, and repeat until all required workflows are green on the same commit.

- [ ] **Step 5: Download and independently unpack the final Actions artifact.**

Calculate SHA-256 of the IPA; inspect `Payload/Vertex2.app/Info.plist`, executable architecture/signing, generated AppIcon/LaunchLogo, AI model directories/notices/manifest, Metal library, and absence of signing payloads.

- [ ] **Step 6: Update Draft PR #18 with final verified commit, workflow run IDs, artifact ID, IPA size/SHA-256, feature truth table, and explicit known limitations.**

Keep PR Draft and unmerged unless the user explicitly approves integration.

Commit: `ci: qualify Vertex2 11 release`

---

## Self-Review

- **Spec coverage:** Tasks 1-6 cover startup/loading, Home/New/Open Project, empty new project, New Composition, exact user icon, workspace/panels, AE Timeline, Graph Editor, effects workflow, auxiliary panels, advanced canonical animation, Time Remap, Frame Mix, optical flow, pitch preserve, BPM, gesture recording, preview/export parity, recovery, migration compatibility, CI, IPA audit, and final artifact.
- **Existing-code check:** The plan extends `ProjectAnimation.swift`, `TimelineEngine.swift`, `GraphEditorView.swift`, `LayerAnimationEvaluator.swift`, and `CompositionGraphCompiler.swift`; it does not create duplicate stores/evaluators for functionality already present.
- **Placeholder scan:** No `TBD`, `TODO`, wildcard file paths, or empty implementation comments remain.
- **Type consistency:** `ProjectAnimationChannel` remains the canonical keyframe store; `ProjectTimeRemap` is a separate exact source-time mapping attached to `ProjectLayer`; Graph Editor and Timeline mutate canonical channels through `AnimationEditEngine` and project commands.
- **Truthfulness:** Unsupported future Color/Expression/Tracking/Paint/Particle/advanced 3D roadmap features are not represented as completed 11.0 functionality.
- **Release safety:** Completion requires all final workflows green on one commit plus independent IPA unpack/audit and SHA verification.