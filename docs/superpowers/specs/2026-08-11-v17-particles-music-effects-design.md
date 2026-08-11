# Vertex2 17.0 — Particles, Procedural Graphics, Focus Music, and Effects Expansion Design

Date: 2026-08-11
Base: verified V16 effects-expansion HEAD `4fca3408c674c8fe0fd8e4b643f834fe0f9ebf06`
Target branch: `agent/phase17-particles-music-effects`
Target product: Vertex2 `17.0.0 (17)`

## Goals

V17 must deliver four user-visible outcomes on the same verified source HEAD:

1. Expand the executable effect catalog from 99 to 128 effects without counting reference-only commercial entries as implemented.
2. Fix Focus Music so its generated music is audible during normal editing, including when the device Silent switch is enabled, and make playback state truthful.
3. Expand Focus Music from 6 tracks to at least 30 original offline procedural tracks with meaningfully different arrangements and sound profiles.
4. Implement the roadmap-defined V17 Particles and Procedural Graphics milestone with deterministic simulation, Metal rendering, procedural textures, animation-channel compatibility, tests, and a qualified unsigned iPad IPA.

## Non-goals and licensing boundary

- Do not copy, redistribute, disassemble, or translate commercial plugin code, shaders, presets, audio, or bundled assets.
- Commercial effect names in the 1,568-entry reference catalog remain reference/index entries unless a real Vertex-owned implementation exists.
- Clean-room effects inspired by a visual purpose use Vertex names and independent algorithms built from Apple public APIs and Vertex-owned code.
- Focus Music contains no third-party songs or samples. Every track is synthesized deterministically on-device from Vertex-owned code.
- V17 does not implement the V18 node compositor or V22+ full 3D particle scene integration.

## 1. Focus Music repair and expansion

### Root cause

The current Focus Music player configures `AVAudioSession` as `.ambient`. That category is intentionally silenced by the device Silent switch. For a user-invoked music player, V17 will use `.playback` with `.mixWithOthers` so Focus Music remains audible while still allowing coexistence with other audio.

The current player also ignores the Bool returned by `AVAudioPlayer.play()` and marks itself playing even if playback did not start. V17 must make `isPlaying` reflect the actual start result.

### Playback contract

- Audio session: `.playback`, `.default`, `.mixWithOthers`.
- Generated loop is loaded into `AVAudioPlayer`, prepared, then `play()` must return true before `isPlaying` becomes true.
- Failure to start becomes a visible `errorMessage` rather than a false PLAYING state.
- Pause/resume, previous/next, track change, loop, and persisted volume remain supported.
- Focus Music remains independent from project/timeline audio and is never exported.

### Catalog and synthesis

Expand from 6 to at least 30 tracks grouped conceptually across:

- lo-fi / warm keys,
- ambient / deep focus,
- rain / air-texture,
- synth / space,
- piano / bell / pluck,
- low-pulse night/render,
- minimal/no-distraction,
- brighter creative-flow tracks.

Tracks must differ in more than title/BPM. The synthesizer configuration will support independently varied:

- root, progression, chord voicing,
- pad harmonic profile,
- bass amount,
- pluck/bell/arpeggio amount and subdivision,
- pulse amount,
- air/noise texture,
- brightness,
- stereo motion,
- optional deterministic echo/delay,
- BPM and phase.

Rendered PCM must be demonstrably non-silent.

## 2. Executable effects expansion: 99 -> 128

V17 adds exactly 29 real effects. The target mix is deliberately weighted toward reusable Apple-public primitives and Vertex-owned clean-room chains that complement the reference document.

### Standard/native effects

Examples include additional tone/channel, blur, transform, stylize, and perspective operations that Core Image can render on iPadOS 17+. Each effect must have:

- a `ProjectEffectType`,
- descriptor metadata and typed parameter domains,
- default validation,
- actual preview/export rendering,
- effect-control UI through the descriptor system,
- iPad render-smoke coverage.

### Vertex clean-room looks

Add independent Vertex looks for effect purposes such as glare/glint, light streaks, chromatic lens treatment, analog damage, pixel sorting-like displacement, poster/threshold stylization, and kaleidoscopic/procedural treatments. These must use Vertex names and independent algorithms.

### V17 procedural/particle effects

At least the following user-facing effects/generators are included in the 29-effect expansion:

- Vertex Particle Field
- Vertex Sparks
- Vertex Snow
- Vertex Dust
- Vertex Starfield
- Vertex Trail Particles
- Vertex Fractal Noise
- Vertex Turbulence Texture
- Vertex Plasma
- Vertex Cellular Texture
- Vertex Grid
- Vertex Rings

The exact descriptor names may be refined while keeping the same behavior boundary.

## 3. Particle simulation architecture

### Portable deterministic core

Create a `VertexProcedural` Swift package target with no UIKit/Core Image/Metal dependency. It owns:

- `ParticleEmitter` shape and emission settings,
- birth rate / maximum particle count,
- lifetime and lifetime variance,
- initial position and spread,
- velocity and velocity spread,
- acceleration/gravity,
- directional force,
- seeded turbulence/noise field,
- collision foundation against normalized rectangular bounds,
- particle size/opacity evolution,
- trail-history sampling,
- deterministic seeded random generator,
- analytic state evaluation at exact `RationalTime`.

The simulation must be reproducible: same seed + configuration + exact time produces byte-equivalent particle state ordering.

### Animation integration

Particle/procedural user parameters live in normal `ProjectEffect` descriptors. Existing Phase 7 effect animation channels therefore animate birth rate, speed, force, turbulence, size, opacity, seed-related controls where semantically valid, and procedural scale/contrast/evolution without a new project schema.

Project schema remains 5 unless implementation reveals an unavoidable persistence-shape change.

## 4. GPU particle renderer

Extend `VertexRenderMetal` with a dedicated particle renderer rather than emulating the roadmap requirement with CPU-drawn images.

- CPU/portable core computes deterministic particle instances for the requested exact time.
- A Metal render pipeline draws particle point sprites/quads into an RGBA texture.
- Particle rendering uses premultiplied alpha and additive/normal compositing modes as appropriate.
- Procedural sprites can be circles/stars/sparks without bundled copyrighted assets.
- The Metal texture is bridged to the existing native effect path and composited with the source frame.
- Renderer resources/pipelines are reusable rather than recreated for each particle.
- Maximum particle count is bounded for mobile memory/performance.

## 5. Procedural graphics

Vertex-owned procedural generators provide deterministic seeded patterns usable as overlays or full-frame generators:

- fractal/turbulence noise,
- plasma/cloud texture,
- cellular/Voronoi-like texture,
- grid/line pattern,
- rings/radial pattern,
- starfield foundations.

Generation uses public GPU/Core Image primitives or Vertex-owned Metal/math. Seed/evolution/scale parameters must visibly alter output.

## 6. UI

- Add `Particles & Procedural` as a descriptor-driven Effects & Presets category.
- All new controls appear through existing Effect Controls parameter metadata; no parallel hard-coded inspector is introduced.
- Focus Music keeps its existing toolbar popover but gains a larger scrollable catalog and compact grouping/filtering only if needed for usability.
- Playback/error state remains visible.

## 7. Testing and qualification

### TDD gates

Tests are committed and observed failing before production implementation for:

- Focus Music count >= 30;
- nonzero PCM amplitude and valid WAV container;
- playback session policy and truthful playback-start semantics;
- 128 total effect types and 124 native / 4 AI split;
- descriptor completeness and default validation;
- deterministic particle simulation, seed divergence, forces/turbulence, collisions, trails, and bounded counts;
- Metal particle render smoke on Apple CI;
- all 29 new effects rendering to real pixels on a realistic iPad frame;
- existing 99-effect regression.

### Release gate

The final exact V17 HEAD must pass:

- portable Swift tests,
- AI model lock/tooling audit,
- iPad Simulator app tests,
- 29-effect render smoke plus existing regressions,
- particle Metal rendering tests,
- Focus Music tests,
- unsigned iOS 17 arm64 Release build,
- `17.0.0 (17)` identity checks,
- iPad-only landscape checks,
- IPA ZIP integrity and unsigned-state audit,
- AI model and Metal library presence,
- SHA-256 and exact commit provenance,
- GitHub Release `v17.0.0`.

Final artifact: `Vertex2-17.0.0-unsigned.ipa`.
