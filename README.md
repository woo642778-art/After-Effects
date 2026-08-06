# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. The project is intended to remove major workflow and architecture limitations found in mobile editors while approaching the control, fidelity, and extensibility associated with professional desktop motion and post-production systems.

## Current status

**Phase 4 of 28: GPU Render Graph**

Current product version: **4.0.0 (4)**

Implemented:

- exact rational time, stable identity, explicit coordinates and color metadata
- structured dependency and error contracts
- After Effects identity, supplied Ae icon, startup loading, and `Made by Maze`
- once-per-installation Telegram promotion for `https://t.me/aemotionios`
- platform-neutral media descriptors, requests, providers, cancellation, and waveform aggregation
- isolated AVFoundation metadata inspection, thumbnail decoding, and waveform extraction
- real Files-based movie selection and media presentation
- platform-neutral `VertexRender` semantic graph, validation, cache identity, cancellation, and latest-request scheduling
- isolated native `VertexRenderMetal` compute backend
- GPU translation, scale, exposure, saturation, inversion, opacity, and output resizing
- interactive Render Lab using a real imported movie thumbnail
- CPU/GPU/total render metrics
- byte-identical preview and PNG file export
- reproducible unsigned `After-Effects-4.0.0-unsigned.ipa`

Not implemented yet:

- continuous video playback or timeline editing
- multilayer composition or video-file export
- project persistence and recovery
- general effect stacks, motion keyframes, retiming, masks, tracking, AI cutout, shapes, text animation, professional color/audio, particles, node compositing, or 3D

## Build

```bash
swift test
brew install xcodegen
bash Tools/generate_app_assets.sh
xcodegen generate
open Vertex.xcodeproj
```

Every successful phase publishes an **unsigned IPA** through GitHub Actions. Starting with Phase 3, the phase number is the major product version. Installation requires valid signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/MEDIA_IO_ARCHITECTURE.md`
- `Documentation/MEDIA_SOURCE_AUDIT.md`
- `Documentation/MEDIA_TEST_MATRIX.md`
- `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
- `Documentation/GPU_SOURCE_AUDIT.md`
- `Documentation/GPU_TEST_MATRIX.md`
- `Documentation/PHASE_4_COMPLETION.md`
- `Documentation/VERSIONING_AND_ARTIFACTS.md`
- `Documentation/BRANDING_AND_FIRST_RUN.md`
- `Documentation/WORK_LOG.md`
- `Documentation/HANDOFF.md`

## Development rule

A feature is not complete because its UI exists. It is complete only when the underlying behavior, tests, appropriate performance evidence, documentation, and a reproducible build artifact are present.
