# Phase 3 Media Input/Output Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a real iOS media-import vertical slice with platform-neutral media contracts, an AVFoundation adapter, metadata inspection, thumbnail decoding, waveform extraction, and an unsigned `3.0.0` IPA.

**Architecture:** `VertexMedia` owns portable values and protocols and depends only on `VertexCore`. `VertexMediaAVFoundation` is a separate adapter target that translates AVFoundation results without exposing AVFoundation types. The SwiftUI app selects a movie through Files, invokes an actor-backed analyzer, and renders explicit loading, loaded, and failure states.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, UniformTypeIdentifiers, AVFoundation, Accelerate-free PCM aggregation, XcodeGen, GitHub Actions.

## Global Constraints

- Repository: `woo642778-art/After-Effects`.
- Branch: `agent/phase-3-media-io`.
- Base: `agent/phase-2-core-architecture-branding`.
- Minimum deployment target: iOS 17.
- Product display name remains `After Effects`.
- Attribution remains `Made by Maze`.
- Product version is `3.0.0`; build number is `3`.
- Artifact filename is `After-Effects-3.0.0-unsigned.ipa`.
- `VertexMedia` must not import AVFoundation, UIKit, SwiftUI, MetalPetal, VideoIO, or FFmpeg.
- No AVFoundation type may escape `VertexMediaAVFoundation` public interfaces.
- Exact media time uses `RationalTime`; `Double` seconds are display-only.
- UI-only simulations do not count as completed media behavior.

---

### Task 1: Package boundaries and media values

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexMedia/MediaDescriptors.swift`
- Create: `Sources/VertexMedia/MediaRequests.swift`
- Create: `Sources/VertexMedia/MediaProviders.swift`
- Create: `Sources/VertexMedia/MediaError.swift`
- Test: `Tests/VertexMediaTests/MediaContractTests.swift`

**Interfaces:**
- Consumes: `RationalTime`, `VertexID`, `ColorDescriptor`, `VertexSize` from `VertexCore`.
- Produces: `MediaAssetDescriptor`, `VideoStreamDescriptor`, `AudioStreamDescriptor`, `VariableFrameRateStatus`, `VideoFrameRequest`, `AudioWaveformRequest`, `PortableImage`, `AudioWaveform`, `MediaAssetInspecting`, `VideoFrameProvider`, `AudioWaveformProvider`, `MediaCancellationToken`, `MediaBackPressurePolicy`, and `MediaError`.

- [ ] Write failing tests for descriptor validation, request validation, normalized waveform values, cancellation, and a deterministic fake provider.
- [ ] Run `swift test --filter VertexMediaTests` and verify missing-type failures.
- [ ] Add `VertexMedia` and `VertexMediaTests` targets to `Package.swift`.
- [ ] Implement focused portable types with explicit validation errors.
- [ ] Run `swift test` and verify all core and media tests pass.
- [ ] Commit with `feat(media): add portable media contracts`.

### Task 2: AVFoundation asset inspection

**Files:**
- Create: `Sources/VertexMediaAVFoundation/AVFoundationMediaInspector.swift`
- Create: `Sources/VertexMediaAVFoundation/AVFoundationMediaMapping.swift`
- Create: `Tests/VertexMediaAVFoundationTests/AVFoundationInspectorTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Consumes: `MediaAssetInspecting` and descriptor types from `VertexMedia`.
- Produces: `AVFoundationMediaInspector.inspect(url:) async throws -> MediaAssetDescriptor`.

- [ ] Add the adapter and Apple-platform-only test targets.
- [ ] Write mapping tests for dimensions after preferred transform, frame-rate classification, audio channel/sample metadata, and color/HDR mapping.
- [ ] Implement async AVURLAsset property loading and format-description mapping.
- [ ] Return `unknown` when VFR evidence is insufficient.
- [ ] Run `swift test` on macOS-compatible CI and verify all mapping tests pass.
- [ ] Commit with `feat(media): inspect AVFoundation assets`.

### Task 3: Thumbnail provider

**Files:**
- Create: `Sources/VertexMediaAVFoundation/AVFoundationVideoFrameProvider.swift`
- Test: `Tests/VertexMediaAVFoundationTests/VideoFrameProviderTests.swift`

**Interfaces:**
- Consumes: `VideoFrameProvider`, `VideoFrameRequest`, `PortableImage`.
- Produces: PNG-backed `VideoFrame` values with requested and actual exact times.

- [ ] Write tests for request validation, cancellation mapping, preferred-transform application, and bounded target size.
- [ ] Implement actor-isolated `AVAssetImageGenerator` usage.
- [ ] Convert generated `CGImage` to PNG data without leaking CoreGraphics types.
- [ ] Cancel generation when the token or task is cancelled.
- [ ] Run adapter tests and verify deterministic error mapping.
- [ ] Commit with `feat(media): decode requested thumbnails`.

### Task 4: Audio waveform provider

**Files:**
- Create: `Sources/VertexMediaAVFoundation/AVFoundationAudioWaveformProvider.swift`
- Create: `Sources/VertexMedia/WaveformAccumulator.swift`
- Test: `Tests/VertexMediaTests/WaveformAccumulatorTests.swift`
- Test: `Tests/VertexMediaAVFoundationTests/AudioWaveformProviderTests.swift`

**Interfaces:**
- Consumes: `AudioWaveformProvider`, `AudioWaveformRequest`.
- Produces: bounded normalized `AudioWaveform` peak/RMS buckets.

- [ ] Write Linux-compatible accumulator tests with silence, positive/negative full scale, stereo interleaving, and uneven bucket boundaries.
- [ ] Implement a streaming accumulator with bounded memory.
- [ ] Implement `AVAssetReaderTrackOutput` linear-PCM extraction in an actor.
- [ ] Check task and token cancellation between sample buffers.
- [ ] Run all media tests and verify values remain in `0...1`.
- [ ] Commit with `feat(media): extract audio waveforms`.

### Task 5: Real media-import application flow

**Files:**
- Create: `App/MediaImportView.swift`
- Create: `App/MediaImportViewModel.swift`
- Create: `App/WaveformView.swift`
- Modify: `App/RootView.swift`
- Modify: `project.yml`

**Interfaces:**
- Consumes: `AVFoundationMediaInspector`, `AVFoundationVideoFrameProvider`, `AVFoundationAudioWaveformProvider`.
- Produces: user-selectable movie import with real metadata, thumbnail, waveform, cancellation, and error UI.

- [ ] Add the `VertexMedia` and `VertexMediaAVFoundation` products to the Xcode target.
- [ ] Add `NSPhotoLibraryUsageDescription` only if Photos access is used; Files import must not request it.
- [ ] Implement a `@MainActor` view model with `idle`, `loading`, `loaded`, and `failed` states.
- [ ] Use `fileImporter` with `.movie`, security-scoped access, and cancellation of prior analysis.
- [ ] Display exact duration, dimensions, frame rate/VFR, codec, color/HDR, audio metadata, thumbnail, and waveform.
- [ ] Preserve startup loading, icon, `Made by Maze`, and one-time Telegram behavior.
- [ ] Build for generic iOS and resolve only evidenced compiler errors.
- [ ] Commit with `feat(app): add real media inspection flow`.

### Task 6: Phase identity, documentation, CI, and IPA

**Files:**
- Modify: `Sources/VertexCore/Milestone.swift`
- Modify: `project.yml`
- Modify: `.github/workflows/phase-build.yml`
- Create: `Documentation/MEDIA_IO_ARCHITECTURE.md`
- Create: `Documentation/MEDIA_SOURCE_AUDIT.md`
- Create: `Documentation/MEDIA_TEST_MATRIX.md`
- Create: `Documentation/VERSIONING_AND_ARTIFACTS.md`
- Modify: `Documentation/WORK_LOG.md`
- Modify: `Documentation/HANDOFF.md`
- Modify: `README.md`

**Interfaces:**
- Produces: Phase 3 status, persistent handoff, remote evidence, `After-Effects-3.0.0-unsigned.ipa`, and checksum.

- [ ] Set `MARKETING_VERSION: 3.0.0` and `CURRENT_PROJECT_VERSION: 3`.
- [ ] Update milestone data to Phase 3 without claiming playback, timeline, render, or export.
- [ ] Update CI to run core/media tests, compile the AVFoundation adapter, verify `3.0.0 (3)`, package the versioned IPA, and upload it.
- [ ] Run the final workflow at branch HEAD.
- [ ] Download the artifact, inspect its Info.plist, architecture, framework contents, and checksum.
- [ ] Record the exact workflow run, artifact ID, source HEAD, and SHA-256 in the work log and handoff without triggering another product build for documentation-only commits.
- [ ] Open a stacked Draft PR targeting `agent/phase-2-core-architecture-branding`.
- [ ] Commit with `docs: complete Phase 3 handoff and verification`.
