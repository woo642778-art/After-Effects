# Vertex2 Phase 8 Masks & Mattes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Vertex2 8.0.0 with reusable exact-time animation channels, production Bezier masks, alpha/luma track mattes, real Metal execution, editor controls, schema migration, and a verified unsigned IPA.

**Architecture:** Preserve the existing `ProjectLayer -> CompositionGraphCompiler -> RenderGraph -> MetalGraphExecutor` path. Store animation/mask/matte state in `VertexProject`, evaluate exact-time values in `VertexComposition`, represent masks/mattes as renderer-neutral nodes in `VertexRender`, and execute them in `VertexRenderMetal`. All UI mutations continue through project commands so Undo/Redo/autosave/persistence remain valid.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing/XCTest, XcodeGen, AVFoundation, Metal/MetalKit/MSL, canonical `.vertexproject` JSON, iOS 17+.

## Global Constraints

- Correct base is `agent/phase-7-offline-ai-studio` commit `1f471ffede1a28a6e7934c5ae1f392490663a102`.
- Work only on `agent/phase-8-vertex2-motion-masks`.
- Product display name becomes `Vertex2`; internal `Vertex*` module names remain unchanged.
- Bundle identifier remains `com.woo642778.aftereffects`.
- Version becomes `8.0.0 (8)`.
- Final artifact is `Vertex2-8.0.0-unsigned.ipa` and SHA-256.
- App icon comes from the user-supplied person-and-cat photo; crop/resize only, no generated replacement and no text overlay.
- Splash is cosmetic and time-bounded; it must never gate on AI/model/Metal/project readiness.
- Master time remains exact `RationalTime`.
- Preview/export must share the same graph semantics.
- No Core Image or CPU pixel-mask fallback in the V2 render path.
- No placeholder UI presented as completed functionality.
- Existing Phase 7 AI tests and resources must remain intact.

---

### Task 1: Vertex2 Branding, Version, App Icon, and Splash

**Files:**
- Modify: `project.yml`
- Modify: `App/VertexApp.swift`
- Modify: `App/RootView.swift`
- Create: `App/Vertex2SplashView.swift`
- Modify: `App/CompositionWorkspaceView.swift`
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify existing `App/*.xcassets/AppIcon.appiconset/*` after locating exact path
- Test: `Tests/VertexAppTests/AppStartupStateTests.swift`

**Interfaces:**
- Produces user-visible `Vertex2`, version `8.0.0 (8)`, fail-safe launch, photo-based icon set.

- [ ] Update `PRODUCT_NAME`, `CFBundleDisplayName`, `CFBundleName`, marketing/build versions, and unit-test host while preserving bundle ID and target/scheme names.
- [ ] Add `Vertex2SplashView` using a dark background and compact `Vertex2` wordmark; use existing 850 ms app-owned startup timeout so splash presentation cannot deadlock.
- [ ] Replace old visible product strings in root/startup/export filename surfaces.
- [ ] Update milestone catalog to Phase 8 Masks & Mattes.
- [ ] Generate icon derivatives from the supplied square photo using one high-quality RGB master, then replace all declared AppIcon images.
- [ ] Run app startup tests and simulator build through CI before claiming success.
- [ ] Commit as `feat: rebrand release as Vertex2 8.0`.

### Task 2: Reusable Exact-Time Animation Channel Core

**Files:**
- Create: `Sources/VertexProject/ProjectAnimation.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Test: `Tests/VertexProjectTests/ProjectAnimationTests.swift`

**Interfaces:**
- Produces `ProjectPropertyAddress`, `ProjectAnimatableValue`, `ProjectKeyframe`, `ProjectAnimationChannel`, `evaluatedValue(at:)`.

- [ ] Write failing tests for Hold/Linear/Bezier scalar interpolation, exact rational boundaries, endpoint clamping, stable key IDs, duplicate times, invalid handles, type mismatch, and Bezier-path topology mismatch.
- [ ] Implement typed values for scalar/vector2/color/bool/Bezier path.
- [ ] Implement cubic Bezier temporal easing with bounded Newton iterations and bisection fallback.
- [ ] Keep keyframes sorted at validation/mutation boundaries and use binary search during evaluation.
- [ ] Add ordered `animationChannels` to `ProjectLayer` with a decode default of `[]` only through schema migration/compatibility logic, not silent malformed decoding.
- [ ] Commit as `feat: add reusable exact-time animation channels`.

### Task 3: Bezier Mask and Track Matte Project Model + Schema 4

**Files:**
- Create: `Sources/VertexProject/ProjectMask.swift`
- Create: `Sources/VertexProject/Schema3To4Migrator.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexProject/ProjectMigration.swift`
- Modify: `Sources/VertexProject/DeterministicProjectCodec.swift` if compatibility decoding requires it
- Test: `Tests/VertexProjectTests/ProjectMaskTests.swift`
- Test: `Tests/VertexProjectTests/Schema3To4MigrationTests.swift`

**Interfaces:**
- Produces `ProjectMask`, cubic path vertices/tangents, Add/Subtract/Intersect/None, `ProjectTrackMatte`, schema version 4.

- [ ] Write model validation tests for 16-mask limit, 64-vertex limit, finite coordinates, opacity/feather/expansion ranges, IDs, mask property references, and track-matte validity/cycles.
- [ ] Implement mask/path data and deterministic 8-segment-per-cubic flattening utility.
- [ ] Add `masks` and optional `trackMatte` to `ProjectLayer`.
- [ ] Advance `ProjectDocument.currentSchemaVersion` to 4 and `currentAppVersion` to `8.0.0`.
- [ ] Implement deterministic schema 3→4 migration preserving all Phase 7 AI data and initializing animation/mask/matte state.
- [ ] Add migration registry step and canonical-byte tests.
- [ ] Commit as `feat: add schema 4 masks and track mattes`.

### Task 4: Transactional Commands, Undo/Redo, and Autosave for Animation/Masks/Mattes

**Files:**
- Modify: `Sources/VertexProject/ProjectCommandPayload.swift`
- Modify: `Sources/VertexProject/ProjectMutation.swift`
- Modify: `Sources/VertexProject/ProjectCommands.swift`
- Modify: `Sources/VertexProject/ProjectEditingSession.swift` only if merge semantics need extension
- Test: `Tests/VertexProjectTests/ProjectCommandTests.swift`
- Test: `Tests/VertexProjectTests/ProjectEditingSessionTests.swift`

**Interfaces:**
- Add `setLayerAnimationChannels`, `setLayerMasks`, `setLayerTrackMatte` command payloads with before/after mutations.

- [ ] Write failing command/inverse tests.
- [ ] Prepare changes only for unlocked existing layers; validate complete candidate arrays/matte state before transition publication.
- [ ] Add inverse-safe mutations and apply logic.
- [ ] Verify undo/redo and merge-key coalescing for slider/keyframe edits.
- [ ] Commit as `feat: make motion masks and mattes transactional`.

### Task 5: Exact-Time Layer Evaluation in Composition Compiler

**Files:**
- Create: `Sources/VertexComposition/LayerAnimationEvaluator.swift`
- Modify: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Test: `Tests/VertexCompositionTests/LayerAnimationEvaluatorTests.swift`
- Test: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`

**Interfaces:**
- Produces evaluated `LayerTransform`, evaluated masks, and exact-time property values at `CompositionRenderRequest.time`.

- [ ] Test static fallback, animated position/scale/rotation/opacity, exact-key boundaries, and invalid evaluated transform rejection.
- [ ] Evaluate channel values without mutating the project snapshot.
- [ ] Apply evaluated transform/opacity consistently to media, nested composition, and adjustment paths.
- [ ] Evaluate mask scalar/path channels at exactly the same `RationalTime`.
- [ ] Commit as `feat: evaluate layer motion at exact composition time`.

### Task 6: Renderer-Neutral Mask and Matte Nodes

**Files:**
- Create: `Sources/VertexRender/RenderMask.swift`
- Modify: `Sources/VertexRender/RenderGraph.swift`
- Modify: `Sources/VertexComposition/CompositionGraphCompiler.swift`
- Test: `Tests/VertexRenderTests/RenderMaskTests.swift`
- Test: `Tests/VertexCompositionTests/CompositionGraphCompilerTests.swift`

**Interfaces:**
- Add `RenderNodeKind.mask(RenderMaskStack)` and `.matte(RenderTrackMatteMode)`.
- Mask node arity = 1; matte node ordered arity = `[source, matte]`.

- [ ] Write graph validation tests for arity, finite parameters, segment limits, mode validity, and cache-key determinism.
- [ ] Convert evaluated project masks to deterministic flattened `RenderMaskDefinition` values.
- [ ] Compile source → mask → transform/effects/opacity.
- [ ] Compile matte source through its own source/masks/transform/effects, then source → matte node → composite.
- [ ] Prevent matte-source double-compositing and reject cycles/invalid references at project validation.
- [ ] Increment `CompositionGraphCompiler.compilerVersion` so old render cache keys cannot collide.
- [ ] Commit as `feat: compile mask and matte render nodes`.

### Task 7: Metal Mask/Matte Execution

**Files:**
- Modify: `Sources/VertexRenderMetal/MetalRenderParameters.swift`
- Modify: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Modify: `Sources/VertexRenderMetal/MetalGraphExecutor.swift`
- Modify: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Test: `Tests/VertexRenderMetalTests/MetalCompositionPixelTests.swift`

**Interfaces:**
- Add `vertexMaskKernel` and `vertexMatteKernel` compute pipelines.

- [ ] Add failing pixel tests for Add/Subtract/Intersect, invert, opacity, expansion, feather, multiple-mask order, animated-mask frame difference, Alpha/Alpha Inverted/Luma/Luma Inverted.
- [ ] Upload deterministic mask headers/segments to Metal buffers for each mask node.
- [ ] In `vertexMaskKernel`, compute ray-crossing inside state plus min point-to-segment distance, expansion/feather coverage, mask opacity/invert, ordered combination, and premultiplied source multiplication.
- [ ] In `vertexMatteKernel`, derive alpha or Rec.709 straight-RGB luma × alpha coverage and inverted coverage.
- [ ] Cache pipelines at resource initialization and retain texture-pool lifetime rules.
- [ ] Run Metal tests and full Swift tests in CI.
- [ ] Commit as `feat: render masks and track mattes in Metal`.

### Task 8: Layer Editor Keyframes, Mask Editor, and Matte Controls

**Files:**
- Modify: `App/CompositionPreviewController.swift`
- Modify: `App/ProjectWorkspaceViewModel.swift`
- Modify: `App/CompositionWorkspaceView.swift`
- Create: `App/MaskEditorOverlay.swift` if the existing file becomes too large
- Test: `Tests/VertexAppTests/Phase8EditorModelTests.swift`

**Interfaces:**
- Expose exact current frame time from preview controller.
- Workspace helpers mutate channel/mask/matte arrays only through project commands.

- [ ] Add current exact-time accessor.
- [ ] Change Transform controls so a property with animation enabled upserts a keyframe at current time; static properties continue to edit static transform.
- [ ] Add diamond/stopwatch controls and key list/interpolation controls for Position X/Y, Scale X/Y, Rotation, Opacity.
- [ ] Add mask list/add/delete/reorder/mode/invert/opacity/feather/expansion controls.
- [ ] Add draggable vertex/tangent overlay mapped between preview coordinates and normalized layer-local mask coordinates; edits must trigger actual render revision.
- [ ] Add mask Path keyframe control.
- [ ] Add matte source picker and Alpha/Alpha Inverted/Luma/Luma Inverted mode picker.
- [ ] Verify save/reopen retains keys/masks/mattes.
- [ ] Commit as `feat: add live layer keyframe mask and matte editor`.

### Task 9: Regression, CI Release Gate, and Unsigned IPA

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Modify/create Phase 8 release workflow only if existing final gate cannot parameterize 8.0
- Modify: `Tools/ai/audit_ipa.py` only if it hard-codes old product/version names
- Test all existing suites.

**Interfaces:**
- Produces GitHub artifact `Vertex2-8.0.0-unsigned-ipa` containing the exact IPA and SHA.

- [ ] Run portable Swift tests including schema 4/motion/masks/mattes.
- [ ] Run native macOS Metal regression including new pixel tests.
- [ ] Preserve native AI inference fixtures for Depth Anything V2 Small, Real-ESRGAN x4v3, and x4v3-denoise.
- [ ] Run iPhone Simulator startup/session/editor tests.
- [ ] Build unsigned iOS 17 arm64 Release with bundled AI models and Metal library.
- [ ] Package `Vertex2-8.0.0-unsigned.ipa`.
- [ ] Audit bundle metadata: `Vertex2`, version `8.0.0`, build `8`, bundle ID unchanged, no `_CodeSignature`, no `embedded.mobileprovision`, arm64 executable, Assets.car, metallib, AI model manifest/models.
- [ ] Independently SHA-256 the final IPA and compare to the artifact checksum.
- [ ] Download the exact successful-head artifact to `/mnt/data` and provide the user a sandbox link.
- [ ] Keep Phase 8 PR draft/unmerged unless the user explicitly requests merge.
