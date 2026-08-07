# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. Features are considered implemented only when their engine behavior, tests, documentation, and reproducible build evidence exist.

## Current status

**Corrected Phase 5 of 28: Project Persistence and Recovery**

Current product version: **5.0.0 (5)**

Implemented:

- exact rational time, stable identity, explicit coordinates and color metadata;
- After Effects identity, supplied Ae icon, startup loading, `Made by Maze`, and one-time Telegram promotion;
- portable media contracts with isolated AVFoundation inspection, thumbnails, and waveform extraction;
- portable `VertexRender` graph with isolated native Metal compute backend;
- GPU transform, exposure, saturation, inversion, opacity, resize, timing metrics, and byte-identical PNG output;
- canonical schema-versioned `.vertexproject` packages;
- deterministic project JSON, matching manifests, and full pending-save transactions;
- session-only bounded Undo/Redo and recent command identity tracking;
- immutable full-document autosaves retaining eight valid unique snapshots;
- bookmark sidecars, fingerprint relinking, and verified optional media embedding;
- non-destructive legacy `.aeproject` inspection and conversion;
- serial app project ownership through `ProjectSessionActor`;
- real create, open, save, export, recovery-decision, legacy-import, Undo, Redo, autosave, embed, and relink flows;
- reproducible unsigned `After-Effects-5.0.0-unsigned.ipa`.

Next required gate:

- reintegrate corrected persistence into Phase 6;
- restore schema 2 Layers, Compositions, compiler, Metal composition, preview, and PNG parity;
- inspect a replacement `After-Effects-6.0.0-unsigned.ipa` before Phase 7 begins.

Not implemented yet:

- continuous playback or a full NLE timeline;
- video-file export;
- motion keyframes, parenting, motion blur, retiming, masks, tracking, AI cutout, shape/text animation, professional color/audio, particles, nodes, or 3D.

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
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/MEDIA_IO_ARCHITECTURE.md`
- `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
- `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- `Documentation/PROJECT_TEST_MATRIX.md`
- `Documentation/PHASE_5_COMPLETION.md`
- `Documentation/PHASE_5_WORK_LOG.md`
- `Documentation/VERSIONING_AND_ARTIFACTS.md`
- `Documentation/HANDOFF.md`

## Development rule

A feature is not complete because its UI exists. Completion requires real underlying behavior, deterministic tests, appropriate performance or failure evidence, accurate documentation, and a reproducible artifact.
