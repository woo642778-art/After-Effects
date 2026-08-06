# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. The project is intended to remove major workflow and architecture limitations found in mobile editors while approaching the control, fidelity, and extensibility associated with professional desktop motion and post-production systems.

## Current status

**Phase 3 of 28: Media Input and Output Foundation**

Current product version: **3.0.0 (3)**

Implemented:

- exact rational time, stable identity, explicit coordinates and color metadata
- structured dependency and error contracts
- After Effects identity, supplied Ae icon, startup loading, and `Made by Maze`
- once-per-installation Telegram promotion for `https://t.me/aemotionios`
- platform-neutral `VertexMedia` descriptors, requests, providers, cancellation, and waveform aggregation
- isolated AVFoundation metadata inspection
- preferred-transform-aware thumbnail decoding at a requested exact time
- normalized audio peak/RMS waveform extraction
- real Files-based movie selection and presentation of metadata, thumbnail, and waveform
- reproducible unsigned `After-Effects-3.0.0-unsigned.ipa`

Not implemented yet:

- timeline playback or editing
- multilayer GPU composition
- preview/export parity
- effects, motion, retiming, masks, tracking, AI cutout, shapes, text animation, color grading, audio effects, particles, nodes, or 3D

## Build

```bash
swift test
brew install xcodegen
bash Tools/generate_app_assets.sh
xcodegen generate
open Vertex.xcodeproj
```

Every successful phase publishes an **unsigned IPA** through GitHub Actions. Starting with Phase 3, the phase number is the major product version. An installable IPA requires valid signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/MEDIA_IO_ARCHITECTURE.md`
- `Documentation/MEDIA_SOURCE_AUDIT.md`
- `Documentation/MEDIA_TEST_MATRIX.md`
- `Documentation/VERSIONING_AND_ARTIFACTS.md`
- `Documentation/BRANDING_AND_FIRST_RUN.md`
- `Documentation/WORK_LOG.md`
- `Documentation/HANDOFF.md`

## Development rule

A feature is not complete because its UI exists. It is complete only when the underlying behavior, tests, performance evidence appropriate to the phase, documentation, and reproducible build artifact are present.
