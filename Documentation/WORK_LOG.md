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

## 2026-08-05 — Phase 2 implementation

### Scope

Core architecture contracts, After Effects product identity, generated icon assets, branded startup loading, `Made by Maze` attribution, and a once-per-installation Telegram promotion.

### Implemented

- Added normalized `RationalTime` with explicit rounding, exact comparison, checked arithmetic, and invalid-timescale or overflow errors.
- Added canonical `VertexID` UUID identity.
- Added explicit pixel and normalized coordinate spaces with validated conversion.
- Added `ColorDescriptor` with primaries, transfer function, matrix, and alpha mode.
- Added stable dependency ordering and explicit cycle failures.
- Added structured `VertexError` domains, codes, messages, and context.
- Added `CoreArchitectureCatalog` so the app and documentation present the same guarantees.
- Added a tested `OneTimePresentationGate` and mapped it to `@AppStorage` in the app.
- Renamed the installed display name to `After Effects` and changed the bundle identifier to `com.woo642778.aftereffects`.
- Stored the exact supplied Ae icon source as lossless base64 and added deterministic icon generation for iPhone, iPad, App Store, and startup assets.
- Added a startup loading view with the supplied logo, `After Effects`, and `Made by Maze`.
- Added a first-install Telegram promotion for `https://t.me/aemotionios`, with Open Telegram and Continue choices.
- Updated the main milestone UI to use the After Effects identity and display the six Phase 2 architecture contracts.
- Updated GitHub Actions to generate assets, verify the compiled display name and arm64 binary, and package a Phase 2 unsigned IPA.

### Verified locally

- A red test run failed because Phase 2 types did not exist.
- After implementation, `swift test` passed under Swift 6.2.1 on Linux.
- The Phase 2 local suite executed 9 tests with 0 failures.
- The platform-neutral core contains no SwiftUI, UIKit, AVFoundation, MetalPetal, or VideoIO dependency.

### Pending remote verification

- macOS asset generation through `Tools/generate_app_assets.sh`.
- XcodeGen generation using the updated `project.yml`.
- SwiftUI compilation for iOS 17.
- AppIcon and LaunchLogo compilation into `Assets.car`.
- `CFBundleDisplayName` verification as `After Effects`.
- Unsigned arm64 IPA packaging and checksum inspection.

### Product functionality at this point

The app remains a milestone and architecture-status shell. Startup, branding, and the once-per-installation Telegram promotion are real application behaviors. No production media import, timeline, renderer, export engine, motion engine, effect engine, tracking, AI cutout, shape editor, text engine, audio engine, color-processing engine, or 3D engine is claimed.

### Next gate

Run the final Phase 2 GitHub Actions workflow, fix only verified build or test failures, download and inspect the unsigned IPA, record its SHA-256 and artifact identifiers, then create or update the stacked Draft PR targeting the Phase 1 branch.
