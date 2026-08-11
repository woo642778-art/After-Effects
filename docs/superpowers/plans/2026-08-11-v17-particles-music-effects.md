# Vertex2 17.0 Particles, Focus Music, and Effects Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Vertex2 17.0.0 with audible and substantially expanded Focus Music, 128 real executable effects, deterministic particle/procedural graphics, a real Metal particle renderer, and a fully audited unsigned iPad IPA.

**Architecture:** Keep project schema 5 by representing new user-facing particle/procedural controls as normal descriptor-driven `ProjectEffect` parameters. Add a platform-neutral `VertexProcedural` simulation target for deterministic exact-time particle state, then render those states through a reusable Metal particle renderer in `VertexRenderMetal`; bridge the rendered texture into the existing native effect preview/export path. Fix Focus Music at the AVAudioSession/player state boundary and expand the deterministic synthesizer rather than bundling copyrighted audio.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, AVFoundation, Core Image, Metal, XcodeGen, GitHub Actions, iPadOS 17.

## Global Constraints

- Product: Vertex2 `17.0.0 (17)`.
- Bundle identifier: `com.woo642778.aftereffects`.
- Target device family: iPad only (`2`).
- Minimum iOS/iPadOS: 17.0.
- Landscape left/right only.
- Final artifact: unsigned arm64 `Vertex2-17.0.0-unsigned.ipa` plus SHA-256 and exact commit SHA.
- Do not copy or redistribute commercial plugin code, shaders, presets, audio, or assets.
- Commercial/reference catalog entries are not implementation claims.
- Focus Music remains local-only, separate from timeline audio, and never exported.
- Keep canonical project schema at 5 unless an unavoidable persisted-shape change is discovered.

---

### Task 1: Focus Music regression tests and root-cause proof

**Files:**
- Modify: `Tests/VertexAppTests/FocusMusicTests.swift`
- Modify: `App/FocusMusicPlayer.swift` only after RED is observed

**Interfaces:**
- Consumes: `FocusMusicTrack`, `FocusMusicSynthesizer.render(track:)`, `FocusMusicPlayer`
- Produces: test contracts for 30+ tracks, non-silent PCM, playback audio-session policy, and truthful play state

- [ ] **Step 1: Write failing tests**

Add tests asserting:

```swift
#expect(FocusMusicTrack.allCases.count >= 30)
```

Parse the WAV `data` section and assert at least one PCM sample has meaningful amplitude:

```swift
#expect(peakAmplitude > 512)
```

Expose an internal testable session policy value and assert:

```swift
#expect(FocusMusicPlayer.audioSessionCategory == .playback)
#expect(FocusMusicPlayer.audioSessionOptions.contains(.mixWithOthers))
```

Add a player-start seam so a fake returning `false` from `play()` leaves `isPlaying == false` and sets an error.

- [ ] **Step 2: Run iPad app tests and verify RED**

Run the current app test workflow on the V17 branch. Expected failures: catalog is 6, no playback category contract, no failed-start seam.

- [ ] **Step 3: Commit RED tests**

Commit message: `test: define Focus Music V17 playback contract`.

---

### Task 2: Fix Focus Music playback and expand to 30+ tracks

**Files:**
- Modify: `App/FocusMusicPlayer.swift`
- Modify: `App/FocusMusicView.swift`
- Test: `Tests/VertexAppTests/FocusMusicTests.swift`

**Interfaces:**
- Produces: `FocusMusicTrack` catalog with at least 30 cases; synthesizer profiles with bass/pluck/pulse/echo variation; `.playback + .mixWithOthers`; truthful playback state

- [ ] **Step 1: Change audio-session policy**

Implement:

```swift
try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
try session.setActive(true)
```

- [ ] **Step 2: Make play state truthful**

Centralize playback start:

```swift
private func start(_ player: AVAudioPlayer) throws {
    guard player.play() else {
        throw FocusMusicError.playbackDidNotStart
    }
    isPlaying = true
}
```

Pause/stop must set `isPlaying = false`.

- [ ] **Step 3: Expand synthesis configuration**

Extend `FocusMusicConfiguration` with independent values for:

```swift
padFundamental, padSecondHarmonic, bass, pluck, bell,
pulse, air, stereoMotion, echo, subdivision
```

Create at least 30 distinct `FocusMusicTrack` cases spanning lo-fi, ambient, rain, synth, piano/bell, night, minimal, and creative-flow profiles.

- [ ] **Step 4: Improve catalog usability**

Keep one popover. Increase its height modestly and show a short mood tag/subtitle; preserve scrollability and previous/next controls.

- [ ] **Step 5: Run Focus Music tests GREEN**

Expected: count >= 30, non-silent WAV, persistence, session policy, and failed-play truthfulness all pass.

- [ ] **Step 6: Commit**

Commit message: `fix: make Focus Music audible and expand original catalog`.

---

### Task 3: Add portable deterministic particle engine

**Files:**
- Modify: `Package.swift`
- Create: `Sources/VertexProcedural/ParticleTypes.swift`
- Create: `Sources/VertexProcedural/ParticleRandom.swift`
- Create: `Sources/VertexProcedural/ParticleSimulation.swift`
- Create: `Tests/VertexProceduralTests/ParticleSimulationTests.swift`

**Interfaces:**
- Produces:
  - `ParticleSystemConfiguration`
  - `ParticleEmitterShape`
  - `ParticleForceField`
  - `ParticleState`
  - `ParticleTrailPoint`
  - `ParticleSimulator.states(configuration:time:)`

- [ ] **Step 1: Add failing portable tests**

Test:
- same seed/config/time -> identical ordered states;
- different seed -> different positions;
- birth/lifetime removes expired particles;
- velocity + acceleration produces expected displacement;
- turbulence changes trajectory but remains deterministic;
- normalized-bound collision keeps particles inside bounds when enabled;
- trails return bounded historical samples;
- maximum particle count is never exceeded.

- [ ] **Step 2: Run `swift test --filter ParticleSimulationTests` and verify RED**

Expected: module/types missing.

- [ ] **Step 3: Implement deterministic RNG and exact-time analytic simulation**

Use a small Vertex-owned seeded PRNG with stable integer arithmetic. Generate births by deterministic birth index, derive each particle's initial state from `(seed, birthIndex)`, then evaluate position/velocity at requested `RationalTime`.

- [ ] **Step 4: Add force/turbulence/collision/trail behavior**

Turbulence is a deterministic smooth value-noise field from seed/time/particle identity, not system randomness.

- [ ] **Step 5: Run portable tests GREEN**

- [ ] **Step 6: Commit**

Commit message: `feat: add deterministic V17 particle simulation`.

---

### Task 4: Add real Metal particle renderer

**Files:**
- Modify: `Package.swift`
- Modify: `project.yml`
- Modify: `Sources/VertexRenderMetal/MetalRenderResources.swift`
- Modify: `Sources/VertexRenderMetal/Shaders/VertexRenderKernels.metal`
- Create: `Sources/VertexRenderMetal/MetalParticleRenderer.swift`
- Create: `Tests/VertexRenderMetalTests/MetalParticleRendererTests.swift`

**Interfaces:**
- Consumes: `[ParticleState]`, output width/height, particle appearance
- Produces: `MetalParticleRenderer.render(...) -> MTLTexture`

- [ ] **Step 1: Write failing Apple-platform renderer test**

Create a small deterministic particle list, render to a 256×144 texture, read bytes, and assert nonzero alpha pixels exist and two repeated renders match byte-for-byte.

- [ ] **Step 2: Verify RED in macOS/iPad CI**

- [ ] **Step 3: Add particle vertex/fragment shaders**

Use instanced quads or point sprites with a soft circular procedural alpha. Support normal and additive blend modes with premultiplied alpha.

- [ ] **Step 4: Add reusable render pipeline resources**

Compile particle vertex/fragment functions in `MetalRenderResources`; do not recreate pipeline states per frame.

- [ ] **Step 5: Implement renderer and deterministic texture clear/draw**

- [ ] **Step 6: Run Metal tests GREEN and commit**

Commit message: `feat: render deterministic particles with Metal`.

---

### Task 5: Define the V17 effect catalog expansion to exactly 128 total

**Files:**
- Modify: `Sources/VertexProject/ProjectEffect.swift`
- Modify: `Sources/VertexProject/ProjectEffectDescriptor.swift`
- Create: `Sources/VertexProject/ProjectEffectV17Descriptors.swift`
- Create: `Tests/VertexProjectTests/Phase17EffectCatalogTests.swift`

**Interfaces:**
- Produces: exactly 29 new `ProjectEffectType` cases and matching descriptors

- [ ] **Step 1: Write failing registry tests**

Assert:

```swift
#expect(ProjectEffectType.allCases.count == 128)
#expect(ProjectEffectType.allCases.filter(\.isNativePixelEffect).count == 124)
#expect(ProjectEffectDescriptorRegistry.all.count == 128)
```

Validate every default effect.

- [ ] **Step 2: Verify RED**

Expected: current counts 99/95/99.

- [ ] **Step 3: Add category**

Add `particlesAndProcedural` with display name `Particles & Procedural`.

- [ ] **Step 4: Add exactly 29 effect cases/descriptors**

Include twelve V17 procedural/particle entries plus seventeen additional standard or Vertex clean-room effects. All commercial-purpose analogs receive Vertex names and independent summaries.

- [ ] **Step 5: Run registry/default validation GREEN and commit**

Commit message: `feat: expand executable effects to 128`.

---

### Task 6: Implement the 17 additional standard/clean-room pixel effects

**Files:**
- Create: `App/NativeV17FrameEffectProcessor.swift`
- Modify: `App/NativeFrameEffectProcessor.swift`
- Create: `Tests/VertexAppTests/NativeV17EffectsRenderTests.swift`

**Interfaces:**
- Consumes: V17 effect descriptors/default parameters
- Produces: real `CIImage` output for all non-particle V17 effects

- [ ] **Step 1: Write aggregate failing render smoke test**

Use a 640×360 asymmetric image. Iterate every V17 non-particle effect, aggregate every missing/unrenderable output, and fail once with the full list.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement Apple-public primitives and Vertex-owned chains**

Use only documented Core Image/public APIs and original chains. Crop infinite-extent outputs to source extent where required.

- [ ] **Step 4: Run test GREEN and commit**

Commit message: `feat: implement V17 clean-room pixel effects`.

---

### Task 7: Integrate particle/procedural effects into preview/export

**Files:**
- Create: `App/ParticleEffectRenderer.swift`
- Create: `App/ProceduralTextureRenderer.swift`
- Modify: `App/NativeV17FrameEffectProcessor.swift`
- Test: `Tests/VertexAppTests/NativeV17EffectsRenderTests.swift`
- Test: `Tests/VertexAppTests/ParticleEffectIntegrationTests.swift`

**Interfaces:**
- `ParticleEffectRenderer.filteredImage(effect:input:time:) throws -> CIImage`
- `ProceduralTextureRenderer.filteredImage(effect:input:time:) throws -> CIImage`

- [ ] **Step 1: Write RED integration tests**

Assert default Vertex Particle Field/Sparks/Snow/Dust/Starfield/Trail Particles render nonempty pixels, are deterministic at the same exact time/seed, and change at a different time or seed.

- [ ] **Step 2: Connect descriptor parameters to `ParticleSystemConfiguration`**

Map birth rate, lifetime, speed, angle/spread, gravity, turbulence, size, opacity, seed, collision, and trail controls.

- [ ] **Step 3: Bridge Metal texture into CIImage**

Use public Metal/Core Image interoperability and composite with source according to the effect's blend behavior.

- [ ] **Step 4: Implement procedural Fractal Noise/Turbulence/Plasma/Cellular/Grid/Rings paths**

Ensure scale/evolution/seed parameters alter real output.

- [ ] **Step 5: Run all 29 V17 effect tests GREEN and commit**

Commit message: `feat: integrate V17 particles and procedural graphics`.

---

### Task 8: V17 version, release notes, and release workflow

**Files:**
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Create: `Documentation/V17_RELEASE_NOTES.md`
- Modify: `.github/workflows/phase12-test-ipa.yml`
- Modify: `.github/workflows/phase16-effects-expansion-validation.yml` or create a V17-specific validation workflow

**Interfaces:**
- Produces: V17 release and qualification automation

- [ ] **Step 1: Set marketing/build identity**

`MARKETING_VERSION: 17.0.0`, `CURRENT_PROJECT_VERSION: 17`, `currentAppVersion = "17.0.0"`.

- [ ] **Step 2: Add V17 workflow contract checks**

Gate on:
- 128 effect count;
- 30+ Focus Music tracks;
- `.playback` Focus Music policy;
- `VertexProcedural` target;
- Metal particle shader/renderer;
- V17 render tests;
- iPad-only/version/bundle contract.

- [ ] **Step 3: Preserve full AI resource audit and iPad app regressions**

- [ ] **Step 4: Package `Vertex2-17.0.0-unsigned.ipa`, SHA file, and commit-sha file**

- [ ] **Step 5: Publish GitHub Release `v17.0.0`**

- [ ] **Step 6: Commit**

Commit message: `release: qualify Vertex2 17.0.0`.

---

### Task 9: Final verification and independent IPA audit

**Files:**
- No product source changes after final qualification HEAD

- [ ] **Step 1: Confirm exact branch HEAD**

Record `agent/phase17-particles-music-effects` SHA.

- [ ] **Step 2: Require all workflows green on the exact same SHA**

Require portable Phase Validation plus V17 iPad/release qualification.

- [ ] **Step 3: Download workflow artifact**

Download `Vertex2-17.0.0-unsigned-ipa`.

- [ ] **Step 4: Independently verify ZIP and SHA**

Run `unzip -t`, compute SHA-256 independently, compare with generated `.sha256`.

- [ ] **Step 5: Inspect extracted app**

Verify:
- `Vertex2`, bundle ID, `17.0.0 (17)`;
- MinimumOSVersion 17.0;
- UIDeviceFamily `[2]`;
- landscape orientations;
- thin arm64 Mach-O;
- no `_CodeSignature`;
- no `embedded.mobileprovision`;
- compiled Metal library present;
- three compiled AI model directories and manifest present.

- [ ] **Step 6: Deliver user-facing files**

Copy to `/mnt/data/Vertex2-17.0.0-unsigned.ipa`, `.sha256`, and `Vertex2-17.0.0-commit-sha.txt` and provide sandbox links.
