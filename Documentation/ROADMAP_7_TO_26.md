# After Effects Roadmap: 7.0.0 to 26.0.0

This document is the detailed forward roadmap after the validated 6.0.0 Layers and Compositions release.

It exists so future implementation work does not lose the intended order, prerequisites, product scope, release numbering, or artifact rules.

## Versioning rule

Each engineering phase maps directly to the public product version:

- Phase 7 -> `7.0.0 (7)` -> `After-Effects-7.0.0-unsigned.ipa`
- Phase 8 -> `8.0.0 (8)` -> `After-Effects-8.0.0-unsigned.ipa`
- ...
- Phase 26 -> `26.0.0 (26)` -> `After-Effects-26.0.0-unsigned.ipa`

A phase is not complete merely because UI exists. A release requires real engine behavior, deterministic tests, iOS Simulator regression coverage where applicable, iOS 17+ arm64 Release build verification, artifact inspection, and a SHA-256 checksum.

## Guiding sequence

The roadmap is intentionally dependency-ordered:

1. Animate values and transforms.
2. Add masks, mattes, and real timeline editing.
3. Add time manipulation, color, audio, text/vector, and tracking.
4. Build a reusable effects architecture and advanced composition system.
5. Add particles, nodes, AI, asset infrastructure, and 3D.
6. Finish with automation, cache, long-project scaling, and export architecture.

---

## 7.0.0 — Motion Engine

### Goal

Create the generic animation foundation that every later animatable property can share.

### Required implementation

- Generic animation channels for scalar, vector, color, boolean/discrete, and other supported property types.
- Stable keyframe identity and exact rational keyframe time.
- Hold interpolation.
- Linear temporal interpolation.
- Cubic Bezier temporal interpolation.
- Ease In, Ease Out, Easy Ease, and editable influence/speed handles.
- Spatial interpolation for 2D position.
- Linear and cubic Bezier motion paths.
- Editable incoming/outgoing spatial tangents.
- Continuous and broken tangent behavior.
- Layer parenting with cycle detection.
- Correct local-to-world transform inheritance.
- Parenting of transform state without incorrectly inheriting opacity as a transform parent property.
- Per-layer motion blur enable.
- Per-composition motion blur enable.
- Shutter angle.
- Shutter phase.
- Deterministic temporal sample placement.
- Premultiplied-alpha accumulation for motion-blur samples.
- Bounded/adaptive sample count suitable for mobile hardware.
- Schema migration for animation channels, keyframes, parenting, and motion-blur settings.
- Keyframe/property editing UI sufficient to create, move, edit, copy, delete, and inspect keys.

### Architectural direction

Current static values such as:

```swift
LayerTransform.opacity: Double
LayerTransform.rotationDegrees: Double
LayerTransform.positionX: Double
```

must evolve toward a reusable animation abstraction conceptually equivalent to:

```swift
Animatable<Double>
Animatable<Vector2>
Animatable<Color>
```

The exact Swift API is determined during the Phase 7 design, but animation cannot be hard-coded only for transforms. Later effects, masks, text, lights, particles, color controls, and other properties must be able to reuse the same channel/keyframe engine.

### Explicitly not Phase 7

- Full NLE timeline.
- Time remapping.
- Mask/rotoscope system.
- Full 3D camera/light rendering.

---

## 8.0.0 — Masks and Mattes

### Goal

Build production-grade layer masking and matte composition on top of the Motion Engine.

### Required implementation

- Bezier mask paths.
- Vertex and tangent editing.
- Animated mask paths through the Phase 7 animation system.
- Feather.
- Expansion.
- Opacity.
- Invert.
- Mask modes including Add, Subtract, and Intersect.
- Multiple masks per layer.
- Alpha matte.
- Alpha inverted matte.
- Luma matte.
- Luma inverted matte.
- Track-matte relationships with cycle/invalid-reference protection.
- GPU mask rasterization/compositing path.
- Preview/export parity.

---

## 9.0.0 — Professional NLE Timeline

### Goal

Turn the existing exact-frame composition workspace into a real multitrack editing timeline.

### Required implementation

- Multitrack timeline UI.
- Continuous playback foundation.
- Playhead scrubbing.
- Exact frame stepping.
- Timeline zoom and pan.
- Trim.
- Split.
- Ripple editing.
- Roll editing.
- Slip editing.
- Slide editing.
- Snapping.
- Multi-select.
- Range selection.
- Source/record workflow foundations where useful on mobile.
- Keyboard/trackpad shortcuts where iPadOS supports them.
- Deterministic edit commands with session Undo/Redo.

---

## 10.0.0 — Time Engine and Retiming

### Goal

Allow time itself to become editable while preserving exact frame semantics.

### Required implementation

- Constant speed changes.
- Reverse.
- Freeze frame.
- Time remapping channels.
- Speed ramps.
- Velocity curves.
- Source-time mapping.
- Frame blending.
- Optical-flow/frame-synthesis integration boundary.
- Deterministic preview/export time mapping.
- Nested composition retiming compatibility.

---

## 11.0.0 — Professional Color, HDR, and Scopes

### Goal

Build a serious grading and color-management pipeline rather than a collection of simple filters.

### Required implementation

- Rec.709.
- Display P3.
- Rec.2020.
- SDR.
- HDR10.
- HLG.
- Log-media detection and transform infrastructure for formats such as Apple Log, S-Log, C-Log, and V-Log where metadata/support allows.
- Log-to-display transforms.
- Linear-light processing where required.
- ACES/OpenColorIO integration research and an architecture that does not block later OCIO support.
- HDR-to-SDR tone mapping.
- Dithering and banding-reduction tools.
- Exposure, Lift, Gamma, Gain, Temperature, and Tint.
- RGB and luma curves.
- Hue vs Hue.
- Hue vs Saturation.
- LUT support.
- CDL support.
- Serial, parallel, and layer-mixer grading structures where justified.
- Power-window integration with masks/tracking.
- Histogram.
- Waveform.
- RGB Parade.
- Vectorscope.
- Before/After, split wipe, and difference/reference views.

---

## 12.0.0 — Audio Studio

### Goal

Add a professional audio path synchronized with the exact project timeline.

### Required implementation

- Multitrack audio editing.
- Sample-accurate timeline operations.
- Track volume and pan.
- Mute and Solo.
- Buses and sends.
- EQ.
- Compressor.
- Limiter.
- Gate.
- De-esser.
- Reverb.
- Delay.
- Voice isolation.
- Noise removal.
- LUFS measurement and normalization.
- BPM/beat detection.
- Beat markers usable by motion editing.
- Vocal/drum/bass/instrument stem-separation integration boundary.
- Caption/subtitle timing foundation.

---

## 13.0.0 — Text and Vector Engine

### Goal

Create native motion-design text and shape systems instead of flattened imported graphics.

### Required implementation

- Text layers.
- High-quality shaping/layout.
- Multilingual text handling.
- Variable font support where platform APIs permit.
- Per-character animation architecture.
- Text animators/selectors.
- Text on path.
- Shape layers.
- Bezier paths.
- Fill and stroke.
- Gradients.
- Trim Paths.
- Repeater.
- Path morphing foundation.
- Boolean shape operations where feasible.
- Phase 7 animation channels for all supported text/vector properties.

---

## 14.0.0 — Tracking, Stabilization, and Rotoscoping

### Goal

Provide real motion analysis that can drive masks, transforms, effects, and stabilization.

### Required implementation

- Point tracking.
- Planar tracking.
- Object tracking.
- Face/body tracking integration where appropriate.
- Tracking data attached to reusable motion channels.
- Mask tracking.
- Manual rotoscope workflow.
- Editable propagation/refinement architecture.
- Stabilization.
- Transform solve application.
- Camera-motion analysis foundation for later 3D.

---

## 15.0.0 — Effects Architecture

### Goal

Establish a scalable effects system before attempting a very large built-in effect catalog.

### Required implementation

- Typed effect descriptors.
- GPU effect ABI/boundary.
- Parameter metadata.
- Phase 7 animation channels for effect parameters.
- Reusable Metal shader/kernel infrastructure.
- Effect stacking and deterministic ordering.
- Mask/matte input compatibility.
- HDR/linear-light metadata and behavior declarations.
- Preset serialization.
- Effect migration/versioning.
- Foundation for custom/internal effect modules without coupling every effect directly to the app UI.

---

## 16.0.0 — Advanced Pre-composition and Nesting

### Goal

Expand basic nested compositions into a robust AE-style composition dependency system.

### Required implementation

- Pre-compose operations.
- Move selected attributes/layers into precomps where supported.
- Nested timing semantics.
- Source replacement.
- Dependency graph validation.
- Collapse-transformations style behavior where technically correct.
- Continuous-rasterization behavior for vector/text sources where applicable.
- Nested cache invalidation.
- Preview/export parity across deep nesting.
- Cycle prevention and deterministic dependency evaluation.

---

## 17.0.0 — Particles and Procedural Graphics

### Goal

Add deterministic GPU-generated motion graphics and simulation primitives.

### Required implementation

- GPU particle system.
- Emitters.
- Particle lifetime and birth controls.
- Velocity and acceleration.
- Forces.
- Turbulence/noise fields.
- Trails.
- Collision foundations.
- Sprite and procedural particle rendering.
- Animated parameters through Phase 7 channels.
- Procedural generators.
- Fractal/noise textures.
- Seeded deterministic simulation for reproducible output.

---

## 18.0.0 — Node Compositor

### Goal

Expose the same underlying render graph through a free node-based compositing workspace while keeping layer-based editing available.

### Required implementation

- Node graph workspace.
- Image/media input nodes.
- Effect nodes.
- Mask/matte nodes.
- Merge/composite nodes.
- Transform nodes.
- Math/utility nodes.
- Parameter linking.
- Group/macro nodes.
- Layer-to-node interoperability.
- Node-to-layer/precomp interoperability where semantics are defined.
- Shared kernels with the layer render system rather than duplicate render engines.

---

## 19.0.0 — AI Studio

### Goal

Integrate useful AI-assisted editing without making core editing depend on online services.

### Required implementation

- Subject/object cutout and segmentation.
- Brush/prompt-assisted masking architecture.
- Depth estimation integration, including a Depth Anything-class model boundary where licensing/device constraints permit.
- AI-assisted tracking/refinement.
- Denoise.
- Deblur/restoration integration boundary.
- Frame interpolation integration boundary.
- Intelligent mask/refinement tools.
- On-device model management where feasible.
- Explicit model provenance, size, license, memory, and hardware requirements.

---

## 20.0.0 — AI Upscale and Restoration

### Goal

Provide a high-quality automatic upscale/restoration workflow comparable in purpose to dedicated AI enhancement tools without claiming model parity that has not been measured.

### Required implementation

- Super-resolution model abstraction.
- Automatic upscale presets.
- 2x/4x or model-supported scale modes.
- Detail restoration.
- Compression-artifact cleanup.
- Face/detail restoration where an appropriate licensed model is available.
- Tiled inference for mobile memory limits.
- Metal/Core ML acceleration where applicable.
- Model download/install/version manager if models are too large to bundle.
- Preview region comparison.
- Deterministic export settings and quality metadata.
- Benchmarking on supported Apple hardware before quality claims.

---

## 21.0.0 — Asset and Preset Ecosystem

### Goal

Remove the friction of repeatedly downloading and importing editing resources manually.

### Required implementation

- In-app asset browser.
- Effect presets.
- Transitions.
- Motion presets.
- LUTs.
- Fonts where redistribution/licensing permits.
- Sound/audio resources where redistribution/licensing permits.
- Overlays and visual assets.
- Search.
- Tags/categories.
- Favorites.
- Recently used assets.
- One-tap/drag insertion into the current project.
- Asset versioning and missing-asset handling.
- Bundled-vs-downloadable asset policy.

---

## 22.0.0 — 3D Foundation

### Goal

Move from 2D composition transforms to a real 2.5D/3D scene foundation.

### Required implementation

- Z position.
- 3D orientation/rotation.
- 3D transform hierarchy.
- 2.5D layers.
- Depth ordering.
- 3D coordinate conversions.
- Basic material representation.
- Scene graph foundations.
- Depth-buffer integration.
- Compatibility with parenting and keyframes.

---

## 23.0.0 — 3D Scene Workspace

### Goal

Provide a dedicated workspace for building and manipulating 3D content that remains connected to the same project/composition system.

### Required implementation

- 3D viewport.
- Orbit/pan/dolly navigation.
- Translation/rotation/scale gizmos.
- Scene hierarchy.
- Mesh representation.
- Material/texture representation.
- GLTF/GLB import as the preferred interchange starting point.
- OBJ or other formats only when justified by tested import support.
- Basic environment representation.
- Selection/inspection tools.
- Project links between 2D compositions and 3D scenes.

---

## 24.0.0 — Camera, Light, and Full 3D Rendering

### Goal

Turn the Phase 6 camera/light data models and Phase 22/23 scene foundation into actual rendered 3D behavior.

### Required implementation

- Perspective cameras.
- Camera animation.
- Real light evaluation.
- Point/directional/spot lights.
- Shadows.
- PBR material foundation.
- Environment lighting.
- Depth of field.
- Near/far clipping.
- Render passes where useful.
- Depth integration with 2D compositing.
- Tracked scene/camera integration.
- Performance-aware mobile rendering path.

---

## 25.0.0 — Expressions, Automation, and Extensibility

### Goal

Allow projects to describe relationships and repeated behavior without manually keyframing every property.

### Required implementation

- Property linking.
- Expression evaluation architecture.
- Deterministic expression sandbox.
- Drivers/constraints.
- Reusable macros.
- Automation hooks.
- Scriptable project operations where safe and supportable.
- Custom tool/effect extension boundary built on the Phase 15 effects architecture.
- Strict resource/time limits so expressions cannot destabilize preview/export.

---

## 26.0.0 — Scale, Cache, and Final Export Architecture

### Goal

Make large projects reliable and provide the production render/export system expected from a professional editor.

### Required implementation

- Memory cache.
- Disk render cache.
- Texture/resource pool.
- Cache dependency invalidation.
- Proxy media.
- Background rendering.
- Render queue.
- Checkpoint/resume architecture.
- Long-project stability testing.
- Large composition/layer-count testing.
- Video-file export.
- H.264/HEVC as platform-supported delivery formats.
- ProRes where platform/device APIs permit.
- HDR export path.
- Alpha-capable export where codecs/platform support it.
- Audio/video muxing and sync verification.
- Preview/export parity verification.
- Export progress, cancellation, failure recovery, and diagnostics.

---

## 27.0.0 — Interchange and Release Qualification

Phase 27 remains the final qualification/interchange phase from the original 28-phase program.

Expected work includes:

- OTIO/XML/AAF interchange research and supported import/export paths.
- Project/package compatibility validation.
- Extension/plugin packaging rules.
- Cross-version migration regression suites.
- Device matrix testing.
- Performance qualification.
- Crash/recovery qualification.
- Release documentation and final acceptance gates.

---

## Phase 7 implementation order

When Phase 7 begins, use this implementation order unless a design review proves a dependency requires adjustment:

1. Generic Animation Channel model.
2. Stable Keyframe model and schema migration.
3. Hold/Linear temporal interpolation.
4. Cubic Bezier temporal interpolation and easing controls.
5. Spatial interpolation and Bezier motion paths.
6. Parenting graph and world-transform evaluation.
7. Motion Blur temporal multisampling.
8. Property/keyframe editing UI.
9. Preview/export parity tests and pixel fixtures.
10. iOS Simulator regression tests.
11. iOS 17+ arm64 Release build.
12. `After-Effects-7.0.0-unsigned.ipa` plus SHA-256 inspection.

## Global non-negotiable gates

No future phase may weaken the following established rules:

- Exact rational time remains authoritative.
- Preview and export must use semantically equivalent render paths.
- Canonical writable project packages use `.vertexproject`.
- Legacy `.aeproject` remains an import-only compatibility path.
- Undo/Redo remains session-only unless a future design is explicitly approved to change that invariant.
- Canonical project JSON must not contain security-scoped bookmark bytes.
- Saves remain crash-safe and recoverable.
- Autosaves remain verified immutable snapshots rather than a mutable command-history substitute.
- New features require deterministic tests and failure-path coverage.
- A release is not complete until its IPA is built, inspected, and checksummed.
- Do not claim AE/DaVinci/Topaz parity unless measured evidence supports that specific claim.

## Current baseline before Phase 7

Validated Phase 6 code baseline:

`c920c11ef78f8a5fa1571bd45ce91617c329b8e7`

Validated product artifact:

`After-Effects-6.0.0-unsigned.ipa`

SHA-256:

`a4ab8fc6d87f06967a34957fc620d304c3bc2a4f56af3c93ab3b08b628f8eec6`
