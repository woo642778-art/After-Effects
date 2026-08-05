# Vertex

Vertex is a long-term iOS-first professional motion-design, compositing, editing, color, audio, 3D, tracking, and AI production system.

The product target is not a cosmetic clone. Vertex is intended to remove the major workflow and architecture limitations found in mobile editors while approaching the control, fidelity, and extensibility associated with After Effects and DaVinci Resolve.

## Current status

**Phase 1 of 28: Repository Foundation and Source Audit**

Implemented in this phase:

- versioned product vision and 28-phase roadmap
- explicit source-adoption and license boundaries
- engine invariants that later work may not violate
- persistent work log and session handoff documents
- minimal SwiftUI milestone shell
- deterministic Swift core tests
- GitHub Actions workflow that packages an unsigned IPA

No production editing engine is claimed in Phase 1.

## Build

```bash
swift test
brew install xcodegen
xcodegen generate
open Vertex.xcodeproj
```

Every buildable phase publishes an **unsigned IPA** through GitHub Actions. An installable IPA requires valid signing credentials supplied by the repository owner.

## Canonical documents

- `Documentation/PRODUCT_VISION.md`
- `Documentation/ROADMAP_28_PHASES.md`
- `Documentation/ENGINE_INVARIANTS.md`
- `Documentation/SOURCE_ADOPTION_MATRIX.md`
- `Documentation/WORK_LOG.md`
- `Documentation/HANDOFF.md`
- `Documentation/BUILD_AND_IPA_POLICY.md`

## Development rule

A feature is not complete because its UI exists. It is complete only when the underlying behavior, persistence, preview/export parity, tests, performance evidence, and documentation are present.
