# Phase 7 — Offline AI Studio Design

Date: 2026-08-07
Branch: `agent/phase-7-offline-ai-studio`
Target version: `7.0.0 (7)`
Target artifact: `After-Effects-7.0.0-unsigned.ipa`

## Status

Approved design. This specification supersedes the earlier plan that used Phase 7 for the Motion Engine. Phase 7 is now the Offline AI Studio release. Motion Engine work is deferred to the next roadmap slot and must be renumbered in roadmap documentation before Phase 7 completion.

## Product objective

Phase 7 must turn AI into real, reusable editing infrastructure rather than isolated demo buttons. Depth, cutout, upscale, and restoration results must work on full video clips, remain usable inside normal projects, require no server, preserve original media, and survive long-running jobs through cache and resume.

The quality target is competitive with desktop restoration tools such as Topaz-class workflows, but no parity claim may be made without measured side-by-side benchmarks. The implementation must optimize for real output quality first, while remaining bounded by iOS thermal, memory, storage, and Neural Engine/GPU limits.

## Non-negotiable constraints

- No cloud inference or required server.
- No subscription-gated remote model API.
- All shipped models and runtime code must have a redistribution/use license explicitly audited before inclusion.
- Original source media is never overwritten.
- AI output must be project-usable derived media or reusable matte/depth assets, not transient previews only.
- Long video jobs must support progress, cancellation, checkpointing, and resume.
- Phase 7 must not regress exact timing, project recoverability, preview/export semantics, or Phase 6 composition behavior.
- AI model initialization must never block app startup.
- Final IPA inspection must prove that expected models and AI resources are physically present in the built application.

---

# Task 0 — Startup Deadlock Elimination

## Confirmed current defect

The Phase 6 app entry currently gates workspace readiness with a hard-coded milestone check equivalent to:

```swift
MilestoneCatalog.current.number == 5
```

With Phase 6 or Phase 7 active, this evaluates false and can leave the splash screen visible forever.

## Required startup state machine

The app startup state is limited to:

```text
splash
workspace
fatalConfigurationError
```

`fatalConfigurationError` is reserved for bundle/configuration damage that makes the UI itself impossible to present. Project inspection, Metal capability inspection, bookmark problems, AI model problems, model checksum failures, and recent-project corruption are not fatal startup blockers.

## Startup flow

```text
Launch
  ↓
Splash minimum presentation interval
  ↓
Workspace
  ↓
Background initialization
  ├─ recent project inspection
  ├─ Metal capability inspection
  ├─ AI hardware capability profiling
  └─ AI model manifest / integrity inspection
```

AI models are lazy-loaded only when an AI operation actually needs them. Large Core ML bundles must not be eagerly compiled/loaded while the splash screen is active.

## Startup regression requirements

Tests must prove:

- Phase number 5, 6, 7, or an arbitrary future phase cannot prevent workspace entry.
- Missing AI model cannot prevent workspace entry.
- Corrupt AI model manifest cannot prevent workspace entry; affected AI capability becomes unavailable with an explicit diagnostic.
- Metal capability failure cannot leave an infinite splash.
- Recent-project corruption cannot leave an infinite splash.
- Cancellation/re-entry of startup async work reaches a terminal state.
- No indefinite `ProgressView` state is allowed.

Task 0 is a release blocker and must be verified before AI integration proceeds.

---

# AI architecture

Create a dedicated AI boundary rather than calling Core ML directly from views.

```text
VertexAI
├── AIModelRegistry
├── AIModelManifest
├── AICapabilityProfiler
├── AIInferenceScheduler
├── AIFramePipeline
├── AIVideoProcessor
├── AIJobStore
├── AIResultCache
├── Depth
├── Segmentation
├── Upscale
└── Restoration
```

UI code submits an immutable AI recipe. The runtime resolves device tier, model, precision, tile size, temporal context, and resource limits. The model implementation remains replaceable without changing project semantics.

## Data flow

```text
Project Media / Layer
        ↓
AI Recipe
        ↓
AIVideoProcessor
        ↓
Exact-time frame decode
        ↓
Preprocess / color normalization
        ↓
Core ML / Vision inference
        ↓
Temporal / tile post-processing
        ↓
Verified cache chunks
        ↓
Derived Media / Matte / Depth Asset
        ↓
Media Registry + Composition Layer usage
```

The AI runtime must not invent a second timing system. Frame requests and baked outputs remain grounded in existing exact project time and source timing.

---

# Device quality tiers

## Preview

Default compatibility tier for supported iOS 17 devices.

- reduced inference resolution;
- aggressive memory limits;
- lightweight models/paths;
- short temporal context;
- fast preview cache generation.

## Balanced

General production tier.

- higher inference resolution;
- temporal smoothing where useful;
- moderate tile overlap;
- quality/performance balance.

## Max Quality

Available by default only for A17 Pro / Apple Silicon M1-class-or-newer hardware when capability checks and memory budget allow.

- maximum validated model resolution;
- larger tile overlap;
- longer temporal context where model supports it;
- higher precision when validated;
- multi-stage restoration where quality improvement is measurable.

The runtime may automatically fall back from Max Quality to Balanced or Preview under memory pressure, thermal pressure, unsupported compute units, or model-specific capability limits. Fallback must be visible to the user and recorded in job diagnostics.

---

# Model policy and licensing gate

No model is considered shipped because its name appears in code. A model reaches the final IPA only after all of the following pass:

1. upstream source identified;
2. code license identified;
3. checkpoint/weight license identified;
4. redistribution terms reviewed;
5. conversion provenance recorded;
6. source checksum recorded;
7. converted/compiled checksum recorded;
8. representative inference fixtures pass;
9. device memory/performance benchmark passes;
10. final IPA contains the expected compiled model/resources.

The manifest records at least:

```json
{
  "modelID": "...",
  "task": "...",
  "upstream": "...",
  "upstreamVersion": "...",
  "license": "...",
  "sourceSHA256": "...",
  "convertedSHA256": "...",
  "precision": "...",
  "compiledSizeBytes": 0,
  "minimumTier": "preview|balanced|max",
  "conversionToolchain": "..."
}
```

## Initial candidate set

### Depth

Primary shipping candidate: Depth Anything V2 Small / Apple-supported Core ML form.

The upstream project states that the Small model is Apache-2.0 while Base/Large/Giant are CC-BY-NC-4.0. Only the Small path is eligible for default bundled evaluation. A currently open upstream discussion questions training-data provenance/commercial-risk interpretation, so the repository must document this uncertainty rather than claiming zero legal risk.

Upstream reference:
`https://github.com/DepthAnything/Depth-Anything-V2`

Video Depth Anything may be benchmarked for temporal consistency, but it is not bundled until its model/checkpoint license and iOS conversion/runtime behavior are independently verified.

### Segmentation / cutout

Fast path:

- Apple Vision person segmentation and foreground-instance APIs where available.

Quality path candidate:

- SAM 2 image/video segmentation.

Meta's upstream README states SAM 2 checkpoints and code are Apache-2.0. Shipping still requires a successful Core ML/iOS conversion or an otherwise acceptable fully local runtime, plus memory and latency validation.

Upstream reference:
`https://github.com/facebookresearch/sam2`

### Upscale

Primary candidate family:

- Real-ESRGAN general restoration/upscale;
- anime/video-oriented Real-ESRGAN variant when it measurably improves AMV/GMV/game footage.

Shipping requires separate verification of repository license and model-weight redistribution terms, plus a reproducible conversion pipeline.

Upstream reference:
`https://github.com/xinntao/Real-ESRGAN`

### Restoration

Candidates are benchmarked rather than blindly bundled:

- NAFNet for efficient denoise/deblur candidates;
- Restormer for high-quality restoration candidates;
- SwinIR for denoise/JPEG artifact/SR candidates;
- GFPGAN for optional face restoration if its model files and dependencies pass the same redistribution audit.

Only candidates with objective quality benefit and acceptable iOS memory/runtime behavior survive into the final package.

---

# Depth Map pipeline

Depth is not an 8-bit preview effect. The system keeps a high-precision internal representation suitable for downstream compositing.

Required controls and outputs:

- high-precision normalized depth representation;
- preview visualization;
- invert;
- near/far remap;
- levels/range adjustment;
- smoothing;
- edge refinement;
- temporal stabilization/smoothing for video where validated;
- export/bake as reusable depth media or project depth asset.

Required editing use cases:

- depth matte;
- depth-driven blur foundation;
- depth-driven displacement/parallax foundation;
- foreground/background isolation;
- future fog/3D/depth compositing input.

The Phase 7 UI must let a generated depth result be registered and used in the project instead of only saving an external image.

---

# Cutout / segmentation pipeline

## Fast path

Use Apple Vision where it provides a robust on-device person or foreground mask with no extra bundled model.

## Quality path

The quality engine must support a prompt-driven object workflow when the validated model/runtime allows it:

- tap/point prompt;
- box prompt;
- brush add/remove prompt;
- multiple object selection;
- foreground/background correction;
- temporal propagation across a clip;
- edge refinement;
- feather/cleanup controls.

The final output is a real alpha matte/matte sequence associated with source timing. It must be usable by normal compositing, effects, color, blur, background replacement, and export paths.

The original RGB media remains untouched.

---

# Upscale pipeline

Required user controls:

- 1x restoration-only mode;
- 2x;
- 3x;
- 4x;
- custom target resolution constrained by validated resource limits;
- general vs anime/game-oriented model profile where both are available;
- denoise/detail/artifact controls only when the chosen model meaningfully supports them.

Large frames use overlapping tiles with seam-safe blending. Tile size and overlap are part of the quality profile and can be reduced automatically under memory pressure.

The pipeline must preserve timing and generate derived high-resolution media that can replace or coexist with the original source inside the project.

---

# Restoration pipeline

Restoration is composable and distinct from scale change.

Candidate operations:

- denoise;
- deblur;
- compression/JPEG/block artifact reduction;
- detail recovery;
- optional face restoration.

The runtime may implement these as one or more model passes. A multi-pass pipeline is enabled only when objective fixtures demonstrate better output than a simpler pass.

No feature may be labeled supported merely because a model file exists; it must produce verified output on device-compatible execution paths.

---

# Video processing, temporal consistency, and scene boundaries

The full-video pipeline is designed around chunked work:

```text
Decode
  ↓
Color normalization
  ↓
Scene-change boundary detection
  ↓
Temporal context assembly
  ↓
Inference
  ↓
Tile overlap reconstruction
  ↓
Temporal consistency / mask propagation
  ↓
Result verification
  ↓
Chunk commit
```

Scene changes reset temporal state when appropriate to avoid propagating depth/masks/details across unrelated shots.

Frame interpolation is explicitly not part of Phase 7. It will be designed later with the Time Engine because interpolation changes source-time semantics, VFR behavior, frame synthesis, and retiming.

---

# AI jobs, progress, cancel, and resume

An AI job has a stable recipe and checkpoint identity derived from:

- source media fingerprint;
- source timing range;
- task type;
- model ID/version/checksum;
- quality tier;
- all user-visible settings;
- output specification.

A resumable job records verified completed chunks rather than trusting an in-memory progress counter.

```text
AIJob
├── recipeDigest
├── sourceFingerprint
├── modelDigest
├── completedChunks
├── pendingChunks
├── failedChunks
├── outputManifest
└── terminalState
```

Resume never accepts a chunk whose source/model/settings digest does not match the current job.

Cancellation stops future work, releases model resources when safe, and keeps already verified reusable chunks unless the user explicitly clears them.

---

# Cache and derived-media semantics

AI is non-destructive.

```text
Original Media
   ├── AI Recipe
   ├── Preview Cache
   └── Baked Derived Media / Matte / Depth
```

Preview/cache data is disposable. Project-relevant baked output is verified before media-registry insertion.

Deleting disposable cache must never damage the original project. If a baked result is intentionally embedded in the project package, it follows existing embedded-media fingerprint and persistence invariants.

Project JSON stores recipe/model identity and references, not arbitrary runtime model state or neural-engine cache blobs.

---

# Performance and memory policy

- Never eagerly load all AI models.
- At most the models necessary for the active pipeline remain resident.
- Use compute-unit selection based on device capability and measured behavior.
- Use autorelease/resource scopes around frame batches where appropriate.
- Use bounded decode and inference queues; do not decode an entire long clip into RAM.
- Apply backpressure between decode, inference, and encode/cache stages.
- Thermal/memory pressure can reduce tier, tile size, temporal context, or concurrency.
- Max Quality must fail or fall back explicitly rather than crashing due to memory pressure.

Benchmarks record at least representative latency, peak memory where measurable, output resolution, device/runtime, and quality profile.

---

# UI design requirements

Phase 7 must expose AI as an editing workflow, not as a diagnostics screen.

Minimum AI workspace capabilities:

- choose source clip/layer;
- select Depth, Cutout, Upscale, or Restoration;
- choose Preview/Balanced/Max Quality when supported;
- show actual active model/profile and fallback reason;
- configure task-specific controls;
- preview representative frame/range;
- start full-clip processing;
- show deterministic progress and current chunk/range;
- cancel;
- resume interrupted jobs;
- inspect output before applying;
- register result into project as derived media/matte/depth;
- clear disposable cache independently from project output.

Missing or invalid models show a capability-specific error. They never turn the whole app into a loading screen.

---

# Artifact content audit

The final build pipeline must produce an artifact inventory containing at least:

- IPA compressed size;
- uncompressed `.app` size;
- main executable size;
- `Assets.car` size;
- all `.metallib` files and sizes;
- all bundled `.mlmodelc`, `.mlpackage`, or other approved model assets and sizes;
- framework/bundle list;
- model manifest;
- application bundle ID;
- display name;
- version/build;
- minimum iOS;
- Mach-O architectures;
- code-signing/provisioning presence or absence;
- IPA SHA-256.

The CI job fails if the Phase 7 model manifest expects a bundled model/resource and it is absent from the packaged `.app`.

A larger IPA is expected only as a consequence of real bundled models/resources. File size itself is not a success metric.

---

# Testing strategy

## Portable tests

- model-manifest validation;
- deterministic recipe hashing;
- quality-tier policy;
- hardware fallback decisions;
- job checkpoint/resume semantics;
- cache key invalidation;
- source/model/settings mismatch rejection;
- derived-media registration rules;
- startup state policy independent of phase number/model availability.

## Native Apple-platform tests

- Core ML model load/inference fixtures for every shipping model;
- Vision segmentation fixture;
- representative image/video frame outputs;
- tile reconstruction seam tests;
- mask/depth alignment tests;
- cancellation/resource-release tests;
- model lazy-loading tests.

## App/Simulator tests

- startup reaches workspace without infinite loading;
- AI model error does not block workspace;
- AI job creation/progress/cancel/resume UI state;
- project insertion of derived AI output;
- existing Phase 6 project/session regressions remain green.

Simulator tests do not substitute for physical-device AI performance validation. Hardware-tier performance claims require measured compatible-device evidence.

---

# Release gates

Phase 7 is complete only if all applicable gates pass:

1. Startup deadlock fixed and regression-tested.
2. Depth Map performs real local inference and creates project-usable video depth output.
3. Cutout performs real local segmentation and creates project-usable alpha/matte output.
4. Upscale processes complete video ranges and creates verified derived media.
5. At least one restoration path produces verified local output.
6. Full-video processing supports progress, cancel, checkpoint, and resume.
7. No required network/server inference path exists.
8. Model/license/conversion manifest is complete for every bundled model.
9. Preview/Balanced/Max Quality device policy is implemented with explicit fallback.
10. Existing Phase 6 composition/persistence tests remain green.
11. iOS app/session tests pass.
12. Native AI fixture tests pass.
13. iOS 17+ arm64 Release build succeeds without signing.
14. Final artifact audit confirms every expected model/resource is physically packaged.
15. Final artifact is named `After-Effects-7.0.0-unsigned.ipa` and has a recorded SHA-256.

---

# Explicit non-goals for 7.0

- AI frame interpolation / FPS conversion;
- Time Remapping / speed ramp engine;
- the previously designed generic Motion Engine/keyframe system;
- full 3D camera/light rendering;
- cloud inference;
- proprietary Topaz models or copied proprietary algorithms;
- claiming Topaz parity without reproducible benchmark evidence.

---

# Roadmap impact

This design intentionally repurposes Phase 7 from Motion Engine to Offline AI Studio based on the approved product-priority change. Before implementation completion, `README.md`, `Documentation/ROADMAP_7_TO_26.md`, and `Documentation/ROADMAP_28_PHASES.md` must be synchronized so there is one canonical numbering scheme. Motion Engine becomes the next planned major engineering release unless the roadmap is explicitly rebalanced again.

# Design invariants

- AI failure is feature-local, never an app-startup deadlock.
- AI work is non-destructive.
- AI results are usable by the normal editor.
- AI jobs are deterministic with respect to source/model/settings identity.
- All inference required by shipped features is local.
- Model inclusion is proven from the final IPA, not inferred from source code.
- Quality claims require measured evidence.
