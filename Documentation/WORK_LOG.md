# Work Log

This file is append-only except for corrections. Each entry records exactly what changed, what was verified, what remains uncertain, and where the next session starts.

## 2026-08-05 — Phase 1 implementation

### Scope

Repository foundation, source-adoption baseline, persistent handoff, minimal milestone app, core tests, and unsigned IPA workflow.

### Implemented

- Replaced the placeholder README with the Vertex product definition and current status.
- Added the complete 28-phase roadmap.
- Added non-negotiable time, render, persistence, truthfulness, and licensing invariants.
- Added a source-adoption matrix for MetalPetal, VideoIO, VideoLab, Cabbage, MiniCut, OpenTimelineIO, and later research dependencies.
- Added a Swift package containing typed milestone and source-adoption records.
- Added deterministic tests for phase identity, source boundaries, GPL isolation, and IPA policy.
- Added a black, white, and red SwiftUI milestone shell that displays the current phase and audited sources.
- Added XcodeGen project configuration.
- Added GitHub Actions jobs for Swift tests and unsigned IPA packaging.
- Added a handoff document designed for continuation in a new conversation.

### Verified locally

- `swift test` passes under Swift 6.2.1 on Linux with 4 tests.
- The Swift package contains no UIKit or SwiftUI dependencies and can be tested independently.

### Verified remotely

- GitHub Actions run `31015258350` completed successfully.
- `VertexCore tests` completed successfully.
- XcodeGen project generation completed successfully.
- Generic iOS Release compilation with code signing disabled completed successfully.
- Unsigned IPA packaging and artifact upload completed successfully.
- Artifact ID: `8934224640`.
- Artifact archive digest: `sha256:2189b4dfb0f6139e081bce4486cf448596bcf2d24ac063a592e2cac6cf9043c2`.
- Extracted IPA SHA-256: `3f86b2ab943e2b7374e2cc9ae905429538619342a07814f379d16d332946a13d`.
- The IPA contains `Payload/Vertex.app/Vertex`, verified as a 64-bit arm64 Mach-O executable.

### Product functionality at this point

The app is a milestone-status shell only. There is no media import, timeline, renderer, export engine, motion engine, effect engine, tracking, AI cutout, shape editor, text engine, audio engine, color engine, or 3D engine yet.

### Phase 1 result

The Phase 1 source, tests, iOS build, unsigned IPA, checksum, documentation, work log, and handoff requirements are complete. The pull request remains draft until final review and merge.

### Next gate

Review and merge PR #1. Phase 2 must begin with the exact-time, identity, coordinate, color, dependency, and error-model specification before production editor functionality is added.
