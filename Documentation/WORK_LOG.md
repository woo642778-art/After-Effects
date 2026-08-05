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

- `swift test` passes under Swift 6.2.1 on Linux.
- The Swift package contains no UIKit or SwiftUI dependencies and can be tested independently.

### Not verified locally

- The iOS application and IPA cannot be compiled in the current Linux execution environment because Xcode and Apple SDKs are unavailable.
- The GitHub macOS workflow must validate XcodeGen generation and the unsigned device build after the branch is pushed.

### Product functionality at this point

The app is a milestone-status shell only. There is no media import, timeline, renderer, export engine, motion engine, effect engine, tracking, AI cutout, shape editor, text engine, audio engine, color engine, or 3D engine yet.

### Next gate

Inspect the GitHub Actions result. If successful, download and checksum the unsigned Phase 1 IPA. If unsuccessful, fix only the build-system cause before beginning Phase 2.
