# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. Features are considered implemented only when their engine behavior, tests, documentation, and reproducible build evidence exist.

## Current status

**Validated Phase 6 of 28: Layers, Compositions, and Multi-Source Rendering**

Current product version: **6.0.0 (6)**

Validated Phase 6 code baseline:

`c920c11ef78f8a5fa1571bd45ce91617c329b8e7`

Final unsigned artifact:

`After-Effects-6.0.0-unsigned.ipa`

SHA-256:

`a4ab8fc6d87f06967a34957fc620d304c3bc2a4f56af3c93ab3b08b628f8eec6`

Implemented through Phase 6:

- exact rational time, stable identity, explicit coordinates and color metadata;
- After Effects identity, supplied Ae icon, startup loading, `Made by Maze`, and one-time Telegram promotion;
- portable media contracts with isolated AVFoundation inspection, thumbnails, and waveform extraction;
- portable `VertexRender` graph with native Metal execution;
- canonical schema-versioned `.vertexproject` packages;
- deterministic project JSON, matching manifests, full pending-save transactions, and crash recovery;
- session-only bounded Undo/Redo;
- immutable full-document autosaves;
- bookmark sidecars, fingerprint relinking, and verified optional media embedding;
- non-destructive legacy `.aeproject` inspection and conversion;
- serial app project ownership through `ProjectSessionActor`;
- schema 2 compositions and layers with stable identities and authoritative Z-order;
- media, adjustment, null, guide, camera, light, and nested-composition layer models;
- Normal, Add, Multiply, and Screen blend modes;
- adjustment-layer and nested-composition rendering;
- multi-source backend-neutral composition render DAG;
- shared Metal preview/output path with deterministic fixtures;
- real iPhone Simulator project/session regression tests;
- reproducible unsigned `After-Effects-6.0.0-unsigned.ipa`.

## Next phase

### 7.0.0 — Motion Engine

Phase 7 is the next required engineering gate. It must establish a reusable animation system rather than hard-coding keyframes only into transforms.

Primary scope:

- generic animation channels;
- stable keyframes with exact rational time;
- Hold, Linear, and Cubic Bezier temporal interpolation;
- Ease In, Ease Out, Easy Ease, and editable temporal handles;
- spatial Bezier motion paths and editable tangents;
- layer parenting and world-transform evaluation with cycle prevention;
- real temporal motion blur with shutter angle, shutter phase, deterministic samples, and premultiplied-alpha accumulation;
- property/keyframe editing UI;
- schema migration and preview/export parity tests;
- final `After-Effects-7.0.0-unsigned.ipa` plus SHA-256 verification.

The planned implementation order is:

`Generic Animation Channel -> Keyframe Model -> Temporal Interpolation -> Spatial Interpolation -> Parenting -> Motion Blur -> UI -> Migration/Regression -> 7.0.0 IPA`

## Future roadmap

The detailed roadmap from **7.0.0 through 26.0.0** is permanently documented in:

- [`Documentation/ROADMAP_7_TO_26.md`](Documentation/ROADMAP_7_TO_26.md)

The canonical full 28-phase index is:

- [`Documentation/ROADMAP_28_PHASES.md`](Documentation/ROADMAP_28_PHASES.md)

High-level version sequence:

| Version | Program |
|---:|---|
| 7.0.0 | Motion Engine |
| 8.0.0 | Masks and Mattes |
| 9.0.0 | Professional NLE Timeline |
| 10.0.0 | Time Engine and Retiming |
| 11.0.0 | Professional Color, HDR, and Scopes |
| 12.0.0 | Audio Studio |
| 13.0.0 | Text and Vector Engine |
| 14.0.0 | Tracking, Stabilization, and Rotoscoping |
| 15.0.0 | Effects Architecture |
| 16.0.0 | Advanced Pre-composition and Nesting |
| 17.0.0 | Particles and Procedural Graphics |
| 18.0.0 | Node Compositor |
| 19.0.0 | AI Studio |
| 20.0.0 | AI Upscale and Restoration |
| 21.0.0 | Asset and Preset Ecosystem |
| 22.0.0 | 3D Foundation |
| 23.0.0 | 3D Scene Workspace |
| 24.0.0 | Camera, Light, and Full 3D Rendering |
| 25.0.0 | Expressions, Automation, and Extensibility |
| 26.0.0 | Scale, Cache, and Final Export Architecture |
| 27.0.0 | Interchange and Release Qualification |

## Build

```bash
swift test
brew install xcodegen
bash Tools/generate_app_assets.sh
xcodegen generate
open Vertex.xcodeproj
```

Every successful phase publishes an unsigned IPA through GitHub Actions. Installation requires signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ROADMAP_7_TO_26.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/MEDIA_IO_ARCHITECTURE.md`
- `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
- `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- `Documentation/PROJECT_TEST_MATRIX.md`
- `Documentation/VERSIONING_AND_ARTIFACTS.md`
- `Documentation/HANDOFF.md`

## Release rule

For Phase `N`, the expected version and artifact are:

`N.0.0 (N)`

`After-Effects-N.0.0-unsigned.ipa`

A phase is not complete because its UI exists. Completion requires real underlying behavior, deterministic tests, appropriate failure/performance evidence, applicable iOS Simulator validation, an iOS 17+ arm64 Release build, accurate documentation, inspected IPA contents, and a verified SHA-256 checksum.
