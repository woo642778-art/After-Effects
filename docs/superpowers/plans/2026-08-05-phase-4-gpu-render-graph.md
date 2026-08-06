# Phase 4 GPU Render Graph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Vertex-owned semantic render graph with a native Metal backend, real imported-media preview, identical PNG export bytes, deterministic tests, and an unsigned After Effects 4.0.0 IPA.

**Architecture:** `VertexRender` defines portable graph, request, result, cache, cancellation, and error contracts. `VertexRenderMetal` implements those contracts with one Metal compute kernel. The app feeds the Phase 3 thumbnail into one request, displays the returned PNG, and exports the same bytes.

**Tech Stack:** Swift 6, Swift Testing, Metal, Metal Shading Language, ImageIO, Core Graphics, SwiftUI, AVFoundation adapter from Phase 3, XcodeGen, GitHub Actions.

## Global Constraints

- Minimum deployment target remains iOS 17.0.
- Product version is exactly `4.0.0 (4)`.
- Artifact filename is exactly `After-Effects-4.0.0-unsigned.ipa`.
- `VertexRender` must not expose Apple framework or third-party types.
- Preview and PNG export must use the same `RenderResult.image.data` bytes.
- MetalPetal and VideoIO are audited but not linked in Phase 4.
- Exact `RationalTime` and explicit `ColorDescriptor` remain authoritative.
- No timeline, continuous playback, video export, multilayer composition, or effect parity is claimed.

---

### Task 1: Portable render contracts and validation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexRender/RenderTypes.swift`
- Create: `Sources/VertexRender/RenderGraph.swift`
- Create: `Sources/VertexRender/RenderBackend.swift`
- Create: `Sources/VertexRender/RenderError.swift`
- Test: `Tests/VertexRenderTests/RenderGraphTests.swift`

**Interfaces:**
- Consumes: `RationalTime`, `VertexID`, `VertexSize`, `ColorDescriptor`, `PortableImage`.
- Produces: `RenderGraph`, `RenderNode`, `RenderOperation`, `RenderRequest`, `RenderResult`, `RenderBackend`.

- [ ] Write failing tests for a valid chain, missing dependency, cycle, invalid dimensions, finite parameter validation, and stable cache keys.
- [ ] Run `swift test` and verify failures identify missing render types.
- [ ] Implement the minimal portable types and deterministic graph validator.
- [ ] Implement canonical cache-key serialization from request values and source-data SHA-256.
- [ ] Run `swift test` and verify all portable tests pass.
- [ ] Commit the portable render contract.

### Task 2: Cancellation and latest-request coordination

**Files:**
- Create: `Sources/VertexRender/RenderScheduling.swift`
- Test: `Tests/VertexRenderTests/RenderSchedulingTests.swift`

**Interfaces:**
- Consumes: `RenderRequest`, `RenderBackend`.
- Produces: `RenderCancellationToken`, `RenderBackPressurePolicy`, `LatestRenderCoordinator`.

- [ ] Write failing async tests for cancellation and latest-request-wins stale-result rejection.
- [ ] Run the focused tests and verify failure.
- [ ] Implement the actor-based token and coordinator.
- [ ] Run the focused tests and full `swift test` suite.
- [ ] Commit scheduling behavior.

### Task 3: Native Metal image backend

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexRenderMetal/MetalRenderBackend.swift`
- Create: `Sources/VertexRenderMetal/MetalImageCodec.swift`
- Create: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Create: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Test: `Tests/VertexRenderMetalTests/MetalRenderBackendTests.swift`

**Interfaces:**
- Consumes: `RenderBackend`, `RenderRequest`, `PortableImage`.
- Produces: `MetalRenderBackend.render(_:, cancellationToken:) async throws -> RenderResult`.

- [ ] Add Apple-platform fixture tests for output dimensions, inversion, opacity, exposure, saturation, scale, and translation.
- [ ] Verify the tests fail before the backend exists.
- [ ] Decode PNG/JPEG with ImageIO into normalized RGBA8 bytes.
- [ ] Create Metal input/output textures and sampler resources.
- [ ] Implement one compute kernel applying transform and color operations in graph order.
- [ ] Execute a command buffer, read output bytes, and encode PNG with explicit color metadata.
- [ ] Populate CPU, GPU, total, pixel, and texture-byte metrics.
- [ ] Run Apple-platform tests and correct only evidence-backed failures.
- [ ] Commit the Metal backend and shader.

### Task 4: Render Lab application integration

**Files:**
- Modify: `App/MediaImportViewModel.swift`
- Modify: `App/MediaImportView.swift`
- Create: `App/RenderLabViewModel.swift`
- Create: `App/RenderLabView.swift`
- Create: `App/RenderExportDocument.swift`
- Test: `Tests/VertexRenderTests/PreviewExportParityTests.swift`

**Interfaces:**
- Consumes: imported `PortableImage`, `MetalRenderBackend`, `LatestRenderCoordinator`.
- Produces: user-adjustable GPU preview and PNG document export.

- [ ] Add a failing parity test proving preview and export consume the same `RenderResult.image.data`.
- [ ] Expose the imported thumbnail to the Render Lab without re-decoding the movie.
- [ ] Implement controls for exposure, saturation, opacity, invert, scale, and normalized translation.
- [ ] Debounce control changes and submit through latest-request-wins coordination.
- [ ] Display rendered PNG, metrics, cache key, and structured errors.
- [ ] Implement `FileDocument` export that writes the exact preview PNG bytes.
- [ ] Run portable tests and iOS compilation.
- [ ] Commit the app vertical slice.

### Task 5: Source audit, architecture documentation, and versioning

**Files:**
- Create: `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
- Create: `Documentation/GPU_SOURCE_AUDIT.md`
- Create: `Documentation/GPU_TEST_MATRIX.md`
- Modify: `Documentation/SOURCE_ADOPTION_MATRIX.md`
- Modify: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `README.md`
- Modify: `project.yml`
- Modify: `.github/workflows/phase-build.yml`

**Interfaces:**
- Produces: persistent technical record and 4.0.0 build policy.

- [ ] Record MetalPetal and VideoIO licenses, reviewed revisions, intended boundaries, and Phase 4 non-adoption decision.
- [ ] Document graph invariants, Metal resource lifetime, color handling, parity rule, limits, and deferred scope.
- [ ] Set marketing version `4.0.0`, build `4`, and artifact names.
- [ ] Add `VertexRender` and `VertexRenderMetal` to the app and test targets.
- [ ] Update CI to run portable tests, compile Metal shaders, verify identity/version, and package the unsigned IPA.
- [ ] Commit documentation and build configuration.

### Task 6: Remote verification and artifact inspection

**Files:**
- Modify after evidence: `Documentation/WORK_LOG.md`
- Modify after evidence: `Documentation/HANDOFF.md`

**Interfaces:**
- Produces: verified CI evidence and downloadable artifact.

- [ ] Push the product-code HEAD and wait for all GitHub Actions jobs.
- [ ] Inspect any compiler or test failure from full logs and apply minimal corrections.
- [ ] Confirm portable tests, Metal shader compilation, XcodeGen, iOS 17 arm64 Release build, identity checks, packaging, and upload pass.
- [ ] Download the artifact and inspect `Info.plist`, Mach-O architecture, assets, IPA contents, and SHA-256.
- [ ] Record exact source HEAD, workflow run, artifact ID, archive digest, IPA digest, test count, limitations, and Phase 5 start gate.
- [ ] Keep PR draft and stacked on Phase 3 until the earlier PRs merge.
