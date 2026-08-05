# After Effects

After Effects is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system made by Maze. Internal engine modules retain the `Vertex` namespace.

The product target is not a cosmetic clone. The project is intended to remove the major workflow and architecture limitations found in mobile editors while approaching the control, fidelity, and extensibility associated with professional desktop motion and post-production systems.

## Current status

**Phase 2 of 28: Core Architecture and Product Identity**

Implemented in this phase:

- exact rational timeline time with explicit rounding and overflow handling
- stable UUID entity identity
- explicit coordinate-space conversion
- explicit color primaries, transfer, matrix, and alpha metadata
- deterministic dependency ordering and cycle detection
- structured subsystem errors
- After Effects display name and user-supplied Ae app icon
- branded startup loading screen with `Made by Maze`
- once-per-installation Telegram promotion for `https://t.me/aemotionios`
- GitHub Actions workflow that generates assets and packages an unsigned Phase 2 IPA

No production editing engine is claimed in Phase 2. Media import, timeline editing, rendering, export, motion, effects, tracking, AI cutout, shapes, text, audio, color processing, and 3D remain future gated phases.

## Build

```bash
swift test
brew install xcodegen
bash Tools/generate_app_assets.sh
xcodegen generate
open Vertex.xcodeproj
```

Every buildable phase publishes an **unsigned IPA** through GitHub Actions. An installable IPA requires valid signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/CORE_ARCHITECTURE.md`
- `Documentation/BRANDING_AND_FIRST_RUN.md`
- `Documentation/WORK_LOG.md`
- `Documentation/HANDOFF.md`
- `Documentation/BUILD_AND_IPA_POLICY.md`

## Development rule

A feature is not complete because its UI exists. It is complete only when the underlying behavior, persistence, preview/export parity, tests, performance evidence, documentation, and reproducible build artifact are present.
