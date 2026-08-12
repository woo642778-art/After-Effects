# Vertex2 17.0 Particles, Procedural Graphics, and Focus Music Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Vertex2 17.0.0 with 113 real executable effects, deterministic time-based GPU particle/procedural graphics, reliable Focus Music playback, at least 24 original offline tracks, and a verified unsigned iPad IPA.

**Architecture:** Extend the existing descriptor-driven effect model with fourteen V17 native effect types. Route them before the V16 expanded Core Image processor into a dedicated Metal compute generator that receives `CompositionEffectRequest.exactCompositionTime`, producing deterministic RGBA overlays that are composited by Core Image. Keep Focus Music isolated from timeline audio, but switch its audio-session policy from `.ambient` to audible `.playback` + `.mixWithOthers` and expand its generated catalog without bundling copyrighted recordings.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation/AVAudioPlayer, Core Image, Metal compute, exact RationalTime, XcodeGen, GitHub Actions.

## Global Constraints

- Marketing version `17.0.0`, build `17`.
- Bundle ID remains `com.woo642778.aftereffects`.
- iPad only (`TARGETED_DEVICE_FAMILY = 2`), minimum iPadOS 17.0.
- Preserve project schema 5 unless canonical persistence shape changes; no schema bump is expected.
- No third-party commercial plugin shaders, binaries, presets, or music recordings.
- Preview/export parity must be deterministic from exact composition time and seed.

---

### Task 1: Lock V17 contracts in tests

**Files:**
- Create: `Tests/VertexProjectTests/Phase17ParticlesAndProceduralTests.swift`
- Create: `Tests/VertexAppTests/V17GPUProceduralRenderTests.swift`
- Modify: `Tests/VertexAppTests/FocusMusicTests.swift`

**Interfaces:**
- Consumes: existing `ProjectEffectType`, descriptor registry, `FocusMusicTrack`, `FocusMusicSynthesizer`.
- Produces: exact expected catalog count `113`, native count `109`, V17 effect names, deterministic render contract, Focus Music count/policy contract.

- [x] Write failing tests before production code.
- [ ] Run Phase Validation and confirm failures are caused by missing V17 symbols/counts and 24-track policy.

### Task 2: Expand Focus Music and fix audible playback

**Files:**
- Modify: `App/FocusMusicPlayer.swift`
- Test: `Tests/VertexAppTests/FocusMusicTests.swift`

**Interfaces:**
- Produces: `FocusMusicPlaybackPolicy`, `FocusMusicTrack.allCases.count >= 24`, playable stereo RIFF/WAVE loops.

- [ ] Replace the six-case catalog with at least twenty-four original deterministic synthesized track definitions.
- [ ] Preserve existing user preference keys and current selected-track behavior.
- [ ] Use `AVAudioSession.Category.playback` with `.mixWithOthers`.
- [ ] Check `prepareToPlay()`/`play()` success and expose failure instead of setting `isPlaying` optimistically.
- [ ] Run Focus Music app tests.

### Task 3: Add V17 effect model and descriptors

**Files:**
- Modify: `Sources/VertexProject/ProjectEffect.swift`
- Modify: `Sources/VertexProject/ProjectEffectExpansionDescriptors.swift`
- Test: `Tests/VertexProjectTests/Phase17ParticlesAndProceduralTests.swift`

**Interfaces:**
- Produces: fourteen new native `ProjectEffectType` cases and descriptors with keyframable scalar controls.

- [ ] Add four particle modes and ten procedural generator modes.
- [ ] Add parameter IDs for seed, birth rate, lifetime, speed, gravity, turbulence, size, hue, intensity, density, scale, angle and secondary controls.
- [ ] Add descriptors using existing `.stylize` category and `.nativePixel` execution mode.
- [ ] Validate all 113 default effects through existing descriptor validation.

### Task 4: Implement deterministic Metal generator

**Files:**
- Create: `App/V17GPUFrameEffectProcessor.swift`
- Modify: `App/NativeFrameEffectProcessor.swift`
- Modify: `App/NativeExpandedFrameEffectProcessor.swift`
- Test: `Tests/VertexAppTests/V17GPUProceduralRenderTests.swift`

**Interfaces:**
- Consumes: `ProjectEffect`, `CIImage`, `RationalTime`.
- Produces: `V17GPUFrameEffectProcessor.filteredImage(effect:input:exactTime:) -> CIImage?`.

- [ ] Compile one Metal compute kernel per process and cache device/queue/pipeline thread-safely per worker thread.
- [ ] Generate particles analytically from seed + exact time with emitter position, birth/lifetime, velocity, gravity, turbulence, reflected-bound collisions, procedural sprites and trail sampling.
- [ ] Generate seeded fractal/value-noise, turbulence, grid, rays, dots, plasma, Voronoi, checker, gradient and star-field textures in the same GPU pass.
- [ ] Composite generated RGBA over the source image and crop to input extent.
- [ ] Route V17 types before the V16 expanded processor so the previous 74-effect smoke set remains unchanged.
- [ ] Run iPad Simulator deterministic render tests at 320×180 or larger.

### Task 5: Version 17 identity and release notes

**Files:**
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Create: `Documentation/V17_RELEASE_NOTES.md`

**Interfaces:**
- Produces: app marketing version `17.0.0`, build `17`, unchanged schema `5`.

- [ ] Update version/build identity only.
- [ ] Document Focus Music fix, 24-track catalog, 14 V17 effects, deterministic GPU architecture, and clean-room licensing boundary.

### Task 6: Release workflow and final qualification

**Files:**
- Modify: `.github/workflows/phase12-test-ipa.yml`

**Interfaces:**
- Produces: `Vertex2-17.0.0-unsigned.ipa`, SHA-256 sidecar, commit SHA sidecar, release logs, GitHub release `v17.0.0`.

- [ ] Retarget workflow to `agent/phase17-particles-focus-audio` and V17 identity checks.
- [ ] Add gates for `ProjectEffectType.allCases.count == 113`, 24 Focus Music tracks, `.playback` policy, and V17 GPU renderer.
- [ ] Run portable tests, AI audits, AI resource preparation, XcodeGen, iPad app tests, unsigned device Release build and IPA audit on the same HEAD.
- [ ] Publish `v17.0.0` only after every gate passes.
- [ ] Download the Actions artifact and independently verify ZIP integrity, bundle metadata, architecture, unsigned state, bundled AI models/Metal libraries and SHA-256.
