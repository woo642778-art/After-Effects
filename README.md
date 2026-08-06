# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. The project is intended to remove major workflow and architecture limitations found in mobile editors while approaching the control, fidelity, and extensibility associated with professional desktop motion and post-production systems.

## Current status

**Phase 6 of 28: Layers and Compositions**

Current product version: **6.0.0 (6)**  
Current project schema: **2**

Implemented:

- exact rational time, stable identity, explicit coordinates and color metadata;
- After Effects identity, supplied Ae icon, startup loading, `Made by Maze`, and one-time Telegram promotion;
- AVFoundation media inspection, exact-frame decoding, thumbnail generation, and waveform extraction;
- deterministic `.aeproject` packages, checksums, journal-first Undo/Redo, atomic save, autosave, recovery, relink, and optional media embedding;
- non-destructive schema 1→2 package migration;
- real Composition and Layer persistence with authoritative Z-order;
- media, Adjustment, Nested Composition, Null, Guide, Camera, and Light layer records;
- real multi-source `VertexRender` DAG;
- Metal position, anchor, independent scale, rotation, opacity, exposure, saturation, and inversion;
- real Normal, Add, Multiply, and Screen blending using premultiplied alpha;
- real Adjustment Layers affecting accumulated layers below;
- real basic Nested Composition rendering with exact source offsets and parent In/Out ranges;
- exact-frame GPU preview and byte-identical PNG output;
- functional composition controls, frame navigation, layer ordering, flags, and inspector;
- reproducible unsigned `After-Effects-6.0.0-unsigned.ipa`.

Model-only in Phase 6:

- Null and Guide layers;
- Camera and Light records and controls.

These types persist and support ordering and Undo/Redo, but Camera and Light do not yet influence pixels.

Not implemented yet:

- continuous playback or a full NLE timeline;
- keyframes, parenting, motion blur, retiming, or advanced pre-composition;
- Camera/Light rendering or video-file export;
- masks, tracking, AI cutout, vector shapes, text animation, professional color/audio, particles, node compositing, or 3D.

## Build

```bash
swift test
brew install xcodegen
bash Tools/generate_app_assets.sh
xcodegen generate
open Vertex.xcodeproj
```

Every successful phase publishes an **unsigned arm64 IPA** through GitHub Actions. Starting with Phase 3, the phase number is the major product version. Installation requires valid Apple signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/MEDIA_IO_ARCHITECTURE.md`
- `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
- `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
- `Documentation/LAYERS_COMPOSITIONS_ARCHITECTURE.md`
- `Documentation/COMPOSITION_TEST_MATRIX.md`
- `Documentation/PHASE_6_COMPLETION.md`
- `Documentation/PHASE_6_WORK_LOG.md`
- `Documentation/VERSIONING_AND_ARTIFACTS.md`
- `Documentation/BRANDING_AND_FIRST_RUN.md`
- `Documentation/HANDOFF.md`

## Development rule

A feature is not complete because its UI exists. It is complete only when the underlying behavior, tests, performance and resource evidence appropriate to the phase, documentation, and a reproducible build artifact are present.
