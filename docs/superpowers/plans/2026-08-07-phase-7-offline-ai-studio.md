# Phase 7 Offline AI Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `7.0.0 (7)` as a fully offline iOS AI editing release with a fixed startup deadlock, real video Depth Map, Cutout, Upscale, Restoration, resumable processing, project-usable derived media, model/license integrity gates, and a verified unsigned IPA.

**Architecture:** Keep app startup independent from AI readiness. Add a portable `VertexAI` domain module for recipes, manifests, capability policy, jobs, cache identities, and project integration; isolate Apple-native inference in `VertexAICoreML`; keep all long-running video work chunked and resumable. Models are pinned by source URL and SHA-256, prepared during CI/build, bundled into the final app, lazy-loaded at runtime, and audited from the packaged IPA.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, AVFoundation, Vision, Core ML, Metal where useful for tile/reconstruction post-processing, XcodeGen, GitHub Actions, Python 3 build tooling for model acquisition/conversion/audit.

## Global Constraints

- Product name: `After Effects`.
- Bundle identifier: `com.woo642778.aftereffects`.
- Minimum iOS: `17.0`.
- Target release: `7.0.0 (7)`.
- Target artifact: `After-Effects-7.0.0-unsigned.ipa`.
- No cloud inference or required runtime server.
- Original source media is never overwritten.
- AI model initialization must never block app startup.
- Full-video AI jobs must support progress, cancellation, checkpointing, and resume.
- Preview/Balanced/Max Quality policy is required; Max Quality defaults to A17 Pro / M1-class-or-newer hardware only when runtime capability and memory budget permit.
- Frame interpolation is not Phase 7 scope.
- No model is shipped until upstream source, code license, checkpoint/weight license, redistribution terms, source SHA-256, converted SHA-256, inference fixture, and iOS-compatible memory/runtime behavior are recorded.
- Phase 6 project persistence invariants remain intact: canonical `.vertexproject`, session-only Undo/Redo, no persisted command history/WAL, no bookmark bytes in project JSON.
- Simulator coverage does not count as physical-device AI performance proof.

---

## File Structure

### New portable AI domain

- `Sources/VertexAI/AIModelManifest.swift` — model identity, license metadata, checksum and bundled-resource contract.
- `Sources/VertexAI/AIQualityTier.swift` — Preview/Balanced/Max Quality and deterministic fallback decisions.
- `Sources/VertexAI/AIRecipe.swift` — immutable task recipes for depth, cutout, upscale, restoration.
- `Sources/VertexAI/AIJob.swift` — resumable chunk/job state and terminal-state model.
- `Sources/VertexAI/AIJobStore.swift` — JSON checkpoint persistence outside canonical project JSON.
- `Sources/VertexAI/AIResultDescriptor.swift` — verified depth/matte/derived-media output metadata.
- `Sources/VertexAI/AICacheKey.swift` — deterministic source/model/settings digests.
- `Sources/VertexAI/AICapabilityProfile.swift` — device capability contract independent from UIKit views.
- `Sources/VertexAI/AIError.swift` — structured AI-specific failures.

### New native inference boundary

- `Sources/VertexAICoreML/AIModelRegistry.swift` — lazy Core ML model location/load/unload.
- `Sources/VertexAICoreML/CoreMLCapabilityProfiler.swift` — native hardware/runtime capability mapping.
- `Sources/VertexAICoreML/DepthInferenceEngine.swift` — depth frame inference.
- `Sources/VertexAICoreML/VisionCutoutEngine.swift` — Vision person/foreground segmentation.
- `Sources/VertexAICoreML/PromptCutoutEngine.swift` — validated prompt-driven quality segmentation runtime.
- `Sources/VertexAICoreML/UpscaleInferenceEngine.swift` — tiled Real-ESRGAN-family inference.
- `Sources/VertexAICoreML/RestorationInferenceEngine.swift` — validated restoration model passes.
- `Sources/VertexAICoreML/AIImageTensorAdapter.swift` — CVPixelBuffer / Core ML tensor conversion.
- `Sources/VertexAICoreML/AITilePlanner.swift` — overlap-safe tile geometry.

### New video pipeline

- `Sources/VertexAIAVFoundation/AIVideoProcessor.swift` — exact-time decode/process/write orchestration.
- `Sources/VertexAIAVFoundation/AIFrameReader.swift` — bounded frame decode.
- `Sources/VertexAIAVFoundation/AIFrameWriter.swift` — verified video/matte/depth output writing.
- `Sources/VertexAIAVFoundation/AISceneBoundaryDetector.swift` — scene-reset boundaries.
- `Sources/VertexAIAVFoundation/AIChunkProcessor.swift` — chunk execution and checkpoint commits.

### Project integration

- `Sources/VertexProject/ProjectAIAsset.swift` — schema-3 AI asset/recipe references.
- `Sources/VertexProject/Schema2To3Migrator.swift` — deterministic migration with no visual change to existing Phase 6 projects.
- `Sources/VertexProject/ProjectSchema.swift` — schema/app version bump and AI registry.
- `Sources/VertexProject/ProjectCommands.swift` — register/remove AI result commands.
- `Sources/VertexProjectPersistence/VertexProjectPackageStore.swift` — preserve schema-3 AI references without storing runtime cache blobs.

### App

- `App/AppStartupState.swift` — bounded startup state machine.
- `App/VertexApp.swift` — remove milestone-number readiness gate.
- `App/AIWorkspaceViewModel.swift` — AI task/job UI orchestration.
- `App/AIWorkspaceView.swift` — source/task/profile/settings/progress/result workflow.
- `App/AIResultPreviewView.swift` — preview result and apply/bake actions.
- `App/RootView.swift` — embed AI workspace without blocking app startup.

### Model/build tooling

- `AI/AI_MODEL_LOCK.json` — pinned upstream files, exact SHA-256, license/source metadata, expected bundle paths.
- `AI/LICENSES/` — redistributed license notices for every shipped model/runtime dependency.
- `Tools/ai/fetch_models.py` — download only pinned model artifacts and verify source SHA-256 before use.
- `Tools/ai/prepare_coreml_models.py` — deterministic conversion/packaging entry point where conversion is required.
- `Tools/ai/audit_models.py` — verify prepared resources against lock/manifest.
- `Tools/ai/audit_ipa.py` — inspect final `.ipa` resource inventory and model presence.
- `.github/workflows/phase-build.yml` — model preparation, native AI tests, 7.0 identity, artifact audit and upload.

---

### Task 0: Eliminate the startup deadlock before AI work

**Files:**
- Create: `App/AppStartupState.swift`
- Modify: `App/VertexApp.swift`
- Test: `Tests/VertexAppTests/AppStartupStateTests.swift`

**Interfaces:**
- Produces: `enum AppStartupState { case splash, workspace, fatalConfigurationError(String) }`
- Produces: `struct AppStartupPolicy { static func terminalState(bundleUIAvailable: Bool) -> AppStartupState }`
- Constraint: Phase/milestone number, AI availability, Metal availability, and recent-project state are not startup blockers.

- [ ] **Step 1: Write failing startup policy tests**

```swift
func testPhaseNumberNeverControlsWorkspaceEntry() {
    XCTAssertEqual(AppStartupPolicy.terminalState(bundleUIAvailable: true), .workspace)
}

func testOnlyMissingRequiredUIBundleCanBecomeFatal() {
    XCTAssertEqual(
        AppStartupPolicy.terminalState(bundleUIAvailable: false),
        .fatalConfigurationError("Required UI resources are unavailable.")
    )
}
```

- [ ] **Step 2: Run the app test target and verify failure**

Run:

```bash
xcodebuild -project Vertex.xcodeproj -scheme Vertex -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Expected: compile failure because `AppStartupPolicy` does not exist.

- [ ] **Step 3: Implement the bounded startup state**

```swift
enum AppStartupState: Equatable {
    case splash
    case workspace
    case fatalConfigurationError(String)
}

struct AppStartupPolicy {
    static func terminalState(bundleUIAvailable: Bool) -> AppStartupState {
        bundleUIAvailable
            ? .workspace
            : .fatalConfigurationError("Required UI resources are unavailable.")
    }
}
```

Replace the `MilestoneCatalog.current.number == 5` gate in `VertexApp.swift` with a finite splash presentation followed by `AppStartupPolicy.terminalState(...)`. Do not await AI/model/project/Metal inspection before setting `.workspace`.

- [ ] **Step 4: Add regression cases for cancelled startup work and arbitrary future milestone values**

The test must instantiate startup state with milestone values `5`, `6`, `7`, and `100` and assert the same terminal workspace state.

- [ ] **Step 5: Run iOS app tests**

Expected: PASS and no test path can leave state permanently `.splash`.

- [ ] **Step 6: Commit**

```bash
git add App/VertexApp.swift App/AppStartupState.swift Tests/VertexAppTests/AppStartupStateTests.swift
git commit -m "fix: eliminate startup splash deadlock"
```

---

### Task 1: Introduce Phase 7 version identity and portable VertexAI module

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Modify: `Sources/VertexCore/Milestone.swift`
- Create: `Sources/VertexAI/AIError.swift`
- Create: `Sources/VertexAI/AIQualityTier.swift`
- Create: `Sources/VertexAI/AICapabilityProfile.swift`
- Test: `Tests/VertexAITests/AIQualityTierTests.swift`

**Interfaces:**

```swift
public enum AIQualityTier: String, Codable, Sendable { case preview, balanced, maxQuality }

public struct AICapabilityProfile: Codable, Equatable, Sendable {
    public var supportsMaxQualityByHardwareClass: Bool
    public var memoryBudgetBytes: UInt64
    public var thermalRestricted: Bool
    public var neuralEngineAvailable: Bool
}

public struct AIQualityDecision: Equatable, Sendable {
    public var requested: AIQualityTier
    public var effective: AIQualityTier
    public var fallbackReason: String?
}
```

- [ ] **Step 1: Add failing quality-tier tests** that prove Max Quality falls back under unsupported hardware, memory, or thermal restrictions and remains Max Quality only on eligible capability profiles.
- [ ] **Step 2: Run `swift test --filter VertexAITests` and verify failure.**
- [ ] **Step 3: Add `VertexAI` product/target/test target to `Package.swift`.**
- [ ] **Step 4: Implement `AIQualityTier`, `AICapabilityProfile`, deterministic `AIQualityPolicy.decide(requested:profile:)`, and structured `AIError`.**
- [ ] **Step 5: Set `MARKETING_VERSION: 7.0.0` and `CURRENT_PROJECT_VERSION: 7` in `project.yml`; update milestone metadata to Offline AI Studio without using milestone data as app-startup readiness.**
- [ ] **Step 6: Run portable tests and commit.**

```bash
git add Package.swift project.yml Sources/VertexCore/Milestone.swift Sources/VertexAI Tests/VertexAITests
git commit -m "feat: establish Phase 7 AI core and quality tiers"
```

---

### Task 2: Pin and audit every model before it can enter the app

**Files:**
- Create: `AI/AI_MODEL_LOCK.json`
- Create: `AI/LICENSES/README.md`
- Create: `Sources/VertexAI/AIModelManifest.swift`
- Create: `Tools/ai/fetch_models.py`
- Create: `Tools/ai/audit_models.py`
- Test: `Tests/VertexAITests/AIModelManifestTests.swift`
- Test: `Tests/Tools/test_ai_model_lock.py`

**Interfaces:**

```swift
public struct AIModelManifestEntry: Codable, Equatable, Sendable {
    public let modelID: String
    public let task: String
    public let upstream: String
    public let upstreamVersion: String
    public let license: String
    public let sourceSHA256: String
    public let convertedSHA256: String?
    public let precision: String
    public let compiledSizeBytes: UInt64?
    public let minimumTier: AIQualityTier
    public let bundleRelativePath: String
}
```

`AI_MODEL_LOCK.json` entries must contain exact downloadable source locations, exact hashes, license identifiers, notice paths, conversion mode (`none` or named deterministic converter), and expected app bundle path.

- [ ] **Step 1: Write lockfile validation tests** requiring 64-hex SHA values, HTTPS upstream URLs, nonempty license IDs, and unique `modelID`/bundle paths.
- [ ] **Step 2: Implement `fetch_models.py` so it downloads to a temporary file, verifies SHA-256 before rename, and fails closed on any mismatch.**
- [ ] **Step 3: Implement `audit_models.py` so an expected resource missing from the prepared model directory exits nonzero.**
- [ ] **Step 4: Add only models whose redistribution terms have been reviewed.** Initial audited candidates are Depth Anything V2 Small for depth, Real-ESRGAN-family models for general/anime upscale, and only restoration/quality-cutout checkpoints whose weight terms pass the same gate. Apple Vision is recorded as a system capability, not a bundled model.
- [ ] **Step 5: Run Python and Swift manifest tests.**
- [ ] **Step 6: Commit lock, notices, tooling, and manifest code.**

```bash
git add AI Sources/VertexAI Tools/ai Tests/VertexAITests Tests/Tools
git commit -m "build: pin and audit offline AI model assets"
```

---

### Task 3: Add schema 3 AI asset references without persisting runtime caches

**Files:**
- Create: `Sources/VertexProject/ProjectAIAsset.swift`
- Create: `Sources/VertexProject/Schema2To3Migrator.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/ProjectMigration.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Test: `Tests/VertexProjectTests/ProjectAISchemaTests.swift`
- Test: `Tests/VertexProjectTests/Schema2To3MigrationTests.swift`

**Interfaces:**

```swift
public enum ProjectAIAssetKind: String, Codable, Sendable {
    case depth, matte, derivedVideo
}

public struct ProjectAIRecipeReference: Codable, Equatable, Sendable {
    public let task: String
    public let modelID: String
    public let modelDigest: String
    public let recipeDigest: String
    public let qualityTier: String
}

public struct ProjectAIAsset: Codable, Equatable, Sendable, Identifiable {
    public let id: VertexID
    public let kind: ProjectAIAssetKind
    public let sourceMediaID: VertexID
    public let outputMediaID: VertexID
    public let recipe: ProjectAIRecipeReference
}
```

- [ ] **Step 1: Write failing schema tests** proving current schema becomes `3`, current app version becomes `7.0.0`, and a schema-2 document migrates to schema 3 with an empty AI asset registry and byte-stable canonical output.
- [ ] **Step 2: Implement `Schema2To3Migrator` without creating fake AI assets or changing existing layer/media/composition semantics.**
- [ ] **Step 3: Add `aiAssetRegistry: [ProjectAIAsset]` to schema 3 and deterministic normalization/validation.**
- [ ] **Step 4: Add session commands `RegisterAIAssetCommand` and `RemoveAIAssetCommand`; keep Undo/Redo session-only.**
- [ ] **Step 5: Verify persistence/autosave/legacy-import regressions.**
- [ ] **Step 6: Commit.**

```bash
git add Sources/VertexProject Tests/VertexProjectTests
git commit -m "feat: add schema 3 AI asset references"
```

---

### Task 4: Build deterministic AI recipes, cache identities, and resumable job storage

**Files:**
- Create: `Sources/VertexAI/AIRecipe.swift`
- Create: `Sources/VertexAI/AICacheKey.swift`
- Create: `Sources/VertexAI/AIJob.swift`
- Create: `Sources/VertexAI/AIJobStore.swift`
- Create: `Sources/VertexAI/AIResultDescriptor.swift`
- Test: `Tests/VertexAITests/AIRecipeTests.swift`
- Test: `Tests/VertexAITests/AIJobStoreTests.swift`

**Interfaces:**

```swift
public enum AITaskRecipe: Codable, Equatable, Sendable {
    case depth(DepthRecipe)
    case cutout(CutoutRecipe)
    case upscale(UpscaleRecipe)
    case restoration(RestorationRecipe)
}

public struct AIJobIdentity: Codable, Equatable, Hashable, Sendable {
    public let sourceFingerprint: String
    public let sourceRangeDigest: String
    public let modelDigest: String
    public let recipeDigest: String
    public let outputDigest: String
}

public enum AIJobTerminalState: String, Codable, Sendable {
    case completed, cancelled, failed
}
```

- [ ] **Step 1: Write tests proving identical recipe/source/model inputs yield identical SHA-256 cache/job identities and any user-visible setting change invalidates the digest.**
- [ ] **Step 2: Write resume tests proving completed chunks are accepted only when source/model/recipe/output digests all match.**
- [ ] **Step 3: Implement canonical JSON encoding for recipes before hashing.**
- [ ] **Step 4: Implement atomic job checkpoint writes under app cache/application-support storage, not inside canonical project JSON.**
- [ ] **Step 5: Implement cancellation semantics that preserve verified completed chunks and stop scheduling future chunks.**
- [ ] **Step 6: Run `swift test --filter VertexAITests` and commit.**

---

### Task 5: Add native Core ML/Vision boundary and lazy model registry

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexAICoreML/AIModelRegistry.swift`
- Create: `Sources/VertexAICoreML/CoreMLCapabilityProfiler.swift`
- Create: `Sources/VertexAICoreML/AIImageTensorAdapter.swift`
- Create: `Sources/VertexAICoreML/AITilePlanner.swift`
- Test: `Tests/VertexAICoreMLTests/AIModelRegistryTests.swift`
- Test: `Tests/VertexAICoreMLTests/AITilePlannerTests.swift`

**Interfaces:**

```swift
public actor AIModelRegistry {
    public func model(for modelID: String) async throws -> MLModel
    public func unload(modelID: String)
    public func unloadAll()
}

public struct AITile: Equatable, Sendable {
    public let inputRect: CGRect
    public let cropRect: CGRect
    public let outputRect: CGRect
}
```

- [ ] **Step 1: Add failing tests proving registry construction does not load models and the first `model(for:)` call performs the load.**
- [ ] **Step 2: Add tile-plan tests for 1080p and 4K inputs proving full coverage, bounded overlap, and no uncovered pixel region.**
- [ ] **Step 3: Add `VertexAICoreML` product/target gated to Apple platforms.**
- [ ] **Step 4: Implement bundle lookup from the verified manifest and `MLModelConfiguration.computeUnits` selection from capability profile.**
- [ ] **Step 5: Implement explicit unload methods and bounded model residency.**
- [ ] **Step 6: Run native tests and commit.**

---

### Task 6: Ship real Depth Map inference and project-usable depth assets

**Files:**
- Create: `Sources/VertexAICoreML/DepthInferenceEngine.swift`
- Create: `Sources/VertexAI/DepthRecipe.swift`
- Modify: `Sources/VertexAI/AIResultDescriptor.swift`
- Create: `Tests/VertexAICoreMLTests/DepthInferenceTests.swift`
- Create: `Tests/VertexAITests/DepthRecipeTests.swift`

**Interfaces:**

```swift
public struct DepthRecipe: Codable, Equatable, Sendable {
    public var invert: Bool
    public var nearValue: Float
    public var farValue: Float
    public var smoothing: Float
    public var edgeRefinement: Float
    public var temporalSmoothing: Float
}

public struct DepthFrame: Sendable {
    public let width: Int
    public let height: Int
    public let values: [Float]
}
```

- [ ] **Step 1: Add a deterministic image fixture and failing inference test requiring finite depth values, correct dimensions, and non-constant depth range.**
- [ ] **Step 2: Implement Core ML preprocessing/inference/postprocessing for the audited Depth Anything V2 Small package. Preserve float depth internally; generate 8-bit visualization only for UI preview.**
- [ ] **Step 3: Implement invert, near/far remap, smoothing and edge-refinement post-processing with validation.**
- [ ] **Step 4: Add alignment tests proving output depth pixel coordinates match source frame orientation/crop semantics.**
- [ ] **Step 5: Add a result descriptor that can later be baked as a project media/depth asset.**
- [ ] **Step 6: Run native tests and commit.**

---

### Task 7: Ship real Cutout with Vision fast path and validated prompt-driven quality path

**Files:**
- Create: `Sources/VertexAI/CutoutRecipe.swift`
- Create: `Sources/VertexAICoreML/VisionCutoutEngine.swift`
- Create: `Sources/VertexAICoreML/PromptCutoutEngine.swift`
- Test: `Tests/VertexAICoreMLTests/VisionCutoutTests.swift`
- Test: `Tests/VertexAICoreMLTests/PromptCutoutTests.swift`

**Interfaces:**

```swift
public enum CutoutPrompt: Codable, Equatable, Sendable {
    case point(x: Double, y: Double, foreground: Bool)
    case box(x: Double, y: Double, width: Double, height: Double)
    case brush(points: [NormalizedPoint], foreground: Bool)
}

public struct CutoutRecipe: Codable, Equatable, Sendable {
    public var mode: CutoutMode
    public var prompts: [CutoutPrompt]
    public var feather: Float
    public var edgeCleanup: Float
}
```

- [ ] **Step 1: Add Vision fixture test producing a nonempty alpha mask for a known person/foreground fixture.**
- [ ] **Step 2: Implement Vision person/foreground path and normalize masks to the source frame coordinate system.**
- [ ] **Step 3: Prepare and validate the prompt-driven quality segmentation model/runtime selected by the model gate. The implementation must remain fully local and must refuse activation if its manifest entry is absent or invalid.**
- [ ] **Step 4: Implement point/box/brush prompt translation and mask add/remove semantics.**
- [ ] **Step 5: Add edge/feather and multiple-object mask composition tests.**
- [ ] **Step 6: Commit only after the quality model's actual inference fixture passes; otherwise keep the quality capability disabled rather than exposing a fake control.**

---

### Task 8: Ship tiled AI Upscale with general and anime/game profiles

**Files:**
- Create: `Sources/VertexAI/UpscaleRecipe.swift`
- Create: `Sources/VertexAICoreML/UpscaleInferenceEngine.swift`
- Create: `Sources/VertexAICoreML/AITileReconstructor.swift`
- Test: `Tests/VertexAICoreMLTests/UpscaleInferenceTests.swift`
- Test: `Tests/VertexAICoreMLTests/AITileReconstructorTests.swift`

**Interfaces:**

```swift
public enum UpscaleProfile: String, Codable, Sendable { case general, animeGame }

public struct UpscaleRecipe: Codable, Equatable, Sendable {
    public var scale: Double
    public var targetWidth: Int?
    public var targetHeight: Int?
    public var profile: UpscaleProfile
}
```

- [ ] **Step 1: Add fixture tests for 2x output size and a tiled-vs-single-frame seam comparison on an input small enough for both paths.**
- [ ] **Step 2: Implement Real-ESRGAN-family Core ML inference using only audited prepared model assets.**
- [ ] **Step 3: Implement 1x restoration-only, 2x, 3x, 4x, and validated custom target resolution. Use AI SR followed by deterministic resampling when exact custom dimensions do not match the native model factor.**
- [ ] **Step 4: Implement overlap blending using weighted crop regions so tile seams are not visible in the reconstruction fixture.**
- [ ] **Step 5: Apply quality-tier tile size/overlap and explicit memory-pressure fallback.**
- [ ] **Step 6: Run native tests and commit.**

---

### Task 9: Select and ship restoration passes by measured benefit

**Files:**
- Create: `Sources/VertexAI/RestorationRecipe.swift`
- Create: `Sources/VertexAICoreML/RestorationInferenceEngine.swift`
- Create: `Tools/ai/benchmark_restoration.py`
- Create: `AI/RESTORATION_BENCHMARKS.json`
- Test: `Tests/VertexAICoreMLTests/RestorationInferenceTests.swift`

**Interfaces:**

```swift
public struct RestorationRecipe: Codable, Equatable, Sendable {
    public var denoiseStrength: Float
    public var deblurStrength: Float
    public var artifactReduction: Float
    public var detailRecovery: Float
    public var faceRestoration: Bool
}
```

- [ ] **Step 1: Define fixed noisy, blurred, compressed and face fixtures plus objective metrics (PSNR/SSIM where a reference exists) and visual regression hashes/previews.**
- [ ] **Step 2: Run the candidate bake-off for NAFNet, Restormer, SwinIR and optional GFPGAN only when each candidate has already passed license/weight redistribution audit. Record model, precision, input size, runtime, and quality metrics in `AI/RESTORATION_BENCHMARKS.json`.**
- [ ] **Step 3: Select the smallest set of winners that materially improve the corresponding fixture without violating iOS memory/runtime constraints; remove losing model entries from the shipping lockfile.**
- [ ] **Step 4: Implement `RestorationInferenceEngine` only for the selected winners and map recipe controls to supported model passes. Unsupported controls remain absent from UI, not no-op.**
- [ ] **Step 5: Add inference regression tests and commit benchmark evidence with implementation.**

---

### Task 10: Implement bounded full-video processing, scene boundaries, progress, cancel and resume

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexAIAVFoundation/AIVideoProcessor.swift`
- Create: `Sources/VertexAIAVFoundation/AIFrameReader.swift`
- Create: `Sources/VertexAIAVFoundation/AIFrameWriter.swift`
- Create: `Sources/VertexAIAVFoundation/AISceneBoundaryDetector.swift`
- Create: `Sources/VertexAIAVFoundation/AIChunkProcessor.swift`
- Test: `Tests/VertexAIAVFoundationTests/AIVideoProcessorTests.swift`
- Test: `Tests/VertexAIAVFoundationTests/AIResumeTests.swift`

**Interfaces:**

```swift
public struct AIVideoProgress: Equatable, Sendable {
    public let completedFrames: Int
    public let totalFrames: Int
    public let completedChunks: Int
    public let totalChunks: Int
}

public actor AIVideoProcessor {
    public func process(job: AIJob, progress: @Sendable (AIVideoProgress) -> Void) async throws -> AIResultDescriptor
    public func cancel(jobID: VertexID)
}
```

- [ ] **Step 1: Add a short generated video fixture and failing tests proving exact output frame count/timing for a no-op test inference engine.**
- [ ] **Step 2: Add bounded decode queue and chunk scheduler; never hold an entire clip's frames in memory.**
- [ ] **Step 3: Implement scene-change boundaries and reset temporal smoothing/propagation state at those boundaries.**
- [ ] **Step 4: Commit each verified output chunk atomically, then checkpoint the job.**
- [ ] **Step 5: Add cancellation test proving no future chunks execute after cancel and verified prior chunks remain resumable.**
- [ ] **Step 6: Add resume test that interrupts after at least one committed chunk, recreates the processor, and finishes without recomputing matching verified chunks.**
- [ ] **Step 7: Run native tests and commit.**

---

### Task 11: Bake depth, matte and enhanced video into project-usable outputs

**Files:**
- Modify: `Sources/VertexAIAVFoundation/AIFrameWriter.swift`
- Modify: `Sources/VertexProject/ProjectAIAsset.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `App/ProjectSessionActor.swift`
- Test: `Tests/VertexProjectTests/ProjectAIAssetCommandTests.swift`
- Test: `Tests/VertexAppTests/AIProjectInsertionTests.swift`

**Interfaces:**

```swift
public struct AIProjectInsertionRequest: Sendable {
    public let result: AIResultDescriptor
    public let sourceMediaID: VertexID
    public let addAsLayer: Bool
}
```

- [ ] **Step 1: Write failing command tests proving a verified derived video is registered as `MediaReference` plus `ProjectAIAsset`, and Undo removes only the new project references, never the original source.**
- [ ] **Step 2: Implement matte/depth outputs as real media/asset references with explicit kind metadata.**
- [ ] **Step 3: Add actor API to insert a verified AI result and optionally create a composition layer using the existing layer command path.**
- [ ] **Step 4: Reject unverified/missing output files before project mutation.**
- [ ] **Step 5: Run project/session/persistence tests and commit.**

---

### Task 12: Build the AI editing workspace without reintroducing startup blocking

**Files:**
- Create: `App/AIWorkspaceViewModel.swift`
- Create: `App/AIWorkspaceView.swift`
- Create: `App/AIResultPreviewView.swift`
- Modify: `App/RootView.swift`
- Modify: `project.yml`
- Test: `Tests/VertexAppTests/AIWorkspaceViewModelTests.swift`

**Interfaces:**

```swift
@MainActor
final class AIWorkspaceViewModel: ObservableObject {
    @Published var selectedTask: AIWorkspaceTask
    @Published var requestedTier: AIQualityTier
    @Published private(set) var effectiveTier: AIQualityTier
    @Published private(set) var progress: AIVideoProgress?
    @Published private(set) var activeFallbackReason: String?
    @Published private(set) var result: AIResultDescriptor?

    func start() async
    func cancel()
    func resume() async
    func applyResult(addAsLayer: Bool) async
}
```

- [ ] **Step 1: Add view-model tests for source selection, tier fallback visibility, start/progress/cancel/resume, missing-model errors, and apply-result state.**
- [ ] **Step 2: Implement task-specific controls: Depth settings, Cutout prompt controls, Upscale scale/profile, Restoration controls. Only expose capabilities actually present in the validated manifest/runtime.**
- [ ] **Step 3: Add representative-frame/range preview before full processing.**
- [ ] **Step 4: Add full-clip job progress, cancel, resume and result inspection.**
- [ ] **Step 5: Embed `AIWorkspaceView` in `RootView`; do not instantiate/load Core ML models during `RootView` creation or app startup.**
- [ ] **Step 6: Run iOS app tests and commit.**

---

### Task 13: Add offline-only, model-presence, resource, and regression CI gates

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Create: `Tools/ai/audit_ipa.py`
- Create: `Tools/ai/assert_offline_runtime.py`
- Test: `Tests/Tools/test_audit_ipa.py`

**Interfaces:**

`audit_ipa.py` writes `artifacts/ipa-inventory.json` with:

```json
{
  "ipaCompressedBytes": 0,
  "appUncompressedBytes": 0,
  "mainExecutableBytes": 0,
  "models": [],
  "metallibs": [],
  "frameworks": [],
  "bundleID": "com.woo642778.aftereffects",
  "displayName": "After Effects",
  "version": "7.0.0",
  "build": "7",
  "minimumOS": "17.0",
  "architectures": ["arm64"],
  "ipaSHA256": "..."
}
```

- [ ] **Step 1: Add CI model acquisition/preparation before Xcode project generation and fail on any lock/hash/license-notice mismatch.**
- [ ] **Step 2: Add native `VertexAICoreMLTests` and `VertexAIAVFoundationTests` jobs on macOS.**
- [ ] **Step 3: Add static runtime-offline audit that rejects new `URLSession`, `NWConnection`, remote HTTP client, or cloud inference code inside `Sources/VertexAI*` and AI app workflow files. Build-time model download tooling under `Tools/ai` is explicitly excluded.**
- [ ] **Step 4: Replace Phase 6 hard-coded version checks with schema 3 / `7.0.0 (7)` checks.**
- [ ] **Step 5: Require expected model bundle paths from `AI_MODEL_LOCK.json` to exist inside the built `.app`.**
- [ ] **Step 6: Run `audit_ipa.py` after packaging and upload the inventory beside IPA and checksum.**
- [ ] **Step 7: Keep Phase 6 portable, persistence, composition, Metal and iOS session tests green.**
- [ ] **Step 8: Commit.**

---

### Task 14: Run final release qualification and publish the unsigned 7.0 IPA

**Files:**
- Modify: `README.md`
- Modify: `Documentation/ROADMAP_28_PHASES.md`
- Modify: `Documentation/ROADMAP_7_TO_26.md`
- Create: `Documentation/PHASE_7_COMPLETION.md`
- Create: `Documentation/PHASE_7_WORK_LOG.md`

**Interfaces:**
- Final artifact name: `After-Effects-7.0.0-unsigned.ipa`.
- Final checksum: `After-Effects-7.0.0-unsigned.ipa.sha256`.
- Final inventory: `ipa-inventory.json`.

- [ ] **Step 1: Renumber the future roadmap so the previously planned Motion Engine moves out of Phase 7 and no document still claims Phase 7 is Motion Engine.**
- [ ] **Step 2: Run all portable Swift tests.**

```bash
swift test
```

- [ ] **Step 3: Run all native AI, Metal, persistence and composition tests on macOS.**
- [ ] **Step 4: Run iPhone Simulator app/session/startup tests and prove the workspace appears without infinite loading when AI models are valid, missing, or intentionally invalidated by test fixtures.**
- [ ] **Step 5: Build Release for generic iOS with signing disabled.**
- [ ] **Step 6: Package exactly `After-Effects-7.0.0-unsigned.ipa`, generate SHA-256, run independent IPA inventory audit, and confirm no `_CodeSignature` or `embedded.mobileprovision` is present.**
- [ ] **Step 7: Confirm every shipping model in `AI_MODEL_LOCK.json` appears physically in the app at the expected path and has the expected prepared checksum.**
- [ ] **Step 8: Record measured model/runtime evidence honestly. Simulator success is not described as physical-device Max Quality performance.**
- [ ] **Step 9: Update README/completion/work-log docs with exact CI run ID, commit SHA, artifact ID, IPA size, model sizes, and SHA-256.**
- [ ] **Step 10: Create a Draft Phase 7 PR targeting `agent/phase-6-layers-compositions`; do not merge it without explicit user approval.**
- [ ] **Step 11: Download the GitHub Actions artifact independently, inspect it again, and only then provide the IPA to the user.**
- [ ] **Step 12: Commit final documentation.**

```bash
git add README.md Documentation
git commit -m "docs: record validated Phase 7 offline AI release"
```

---

## Self-review results

### Spec coverage

- Startup deadlock: Task 0.
- Offline-only architecture: Tasks 2, 5, 13.
- Quality tiers and A17 Pro/M1 Max Quality policy: Tasks 1, 5, 8, 12.
- Model licenses/checksums/final IPA presence: Tasks 2, 13, 14.
- Depth: Task 6.
- Cutout: Task 7.
- Upscale: Task 8.
- Restoration: Task 9.
- Full-video processing and temporal scene boundaries: Task 10.
- Progress/cancel/resume/cache identity: Tasks 4 and 10.
- Project-usable derived media/matte/depth: Tasks 3 and 11.
- AI workspace: Task 12.
- Artifact content audit: Tasks 13 and 14.
- Frame interpolation exclusion: Global Constraints and Task 10.
- Phase 6 persistence/composition regression protection: Tasks 3, 13, 14.

### Placeholder scan

The plan intentionally contains no `TBD`, `TODO`, or fake supported capabilities. Model-dependent controls are enabled only when their audited model/runtime actually passes the defined shipping gate.

### Type consistency

`AIQualityTier`, `AICapabilityProfile`, `AITaskRecipe`, `AIJobIdentity`, `AIResultDescriptor`, `AIModelRegistry`, `AIVideoProcessor`, and `ProjectAIAsset` are introduced before downstream tasks consume them. Runtime cache/checkpoint types remain outside canonical project JSON; only stable AI recipe/model/output references enter schema 3.
