# Phase 5 Completion Record

## Scope

Phase 5 adds a versioned, deterministic, recoverable project system and a real project workspace. It persists media references and Render Lab settings, provides command-based Undo and Redo, records write-ahead journal entries, atomically saves project packages, rotates autosaves, recovers damaged packages non-destructively, relinks missing media using strong identity evidence, and optionally embeds media.

## Implemented modules

### VertexProject

- schema version 1 `ProjectDocument` and `ProjectManifest`;
- portable media references and persistent Render Lab settings;
- deterministic sorted-key JSON, canonical timestamps, and SHA-256;
- structured `ProjectError` values;
- command application with project identity, base revision, precondition, duplicate-ID, inverse, and finite-value checks;
- Undo, Redo, 200-entry bounded history, and compatible command coalescing;
- journal preparation before Undo or Redo mutation;
- checksummed newline-delimited journal records and idempotent replay;
- future-schema metadata inspection and sequential migration registry;
- fingerprint-based media relinking decisions.

### VertexProjectFoundation

- secure `.aeproject` package layout;
- durable temporary writes and same-volume atomic rename;
- project backup, manifest checksum validation, history persistence, and journal append;
- current, previous, and two hourly autosave snapshots;
- recovery candidate inspection and separate recovered-package creation;
- preservation of damaged source packages before recovery writes;
- revision-consistent backup recovery history;
- security bookmark adapter behavior;
- fingerprinted media embedding and embedded-media resolution.

### Application workspace

- create and rename projects;
- open, save, and export project packages;
- display schema and revision;
- register selected media in the current project;
- persist Render Lab settings and output dimensions;
- reflect Undo and Redo back into Render Lab controls;
- write journal records before normal, Undo, and Redo state changes;
- schedule autosaves after edits and on app backgrounding;
- display missing-media state;
- relink using fingerprint verification;
- embed selected media;
- show explicit recovery candidates for damaged packages.

## Debugging and quality record

1. The first Phase 5 CI run intentionally failed because schema and codec tests referenced types that did not exist.
2. Command, journal, relinking, package, recovery, and embedding behavior were each introduced after corresponding failing tests.
3. Canonical ISO-8601 timestamps lose sub-millisecond in-memory precision by design. Package verification was corrected to require canonical `decode → re-encode` byte identity instead of raw `Date` object equality.
4. The first iOS app build failed because the project recovery view did not import `VertexProjectFoundation`. Adding the module import resolved the cascading SwiftUI generic errors.
5. Bookmark creation and resolution were split into platform-correct iOS and macOS options.
6. Undo and Redo initially mutated memory before appending the journal. The history API now invokes a journal preparation callback first; failed preparation leaves project and history unchanged.
7. Backup recovery initially paired an older backup project with the current newer history. Backup candidates now use empty history unless a revision-matched backup history is added in a future schema.
8. Render Lab now observes project revision changes so Undo and Redo update visible controls as well as persistent state.

## Final verification

- Product and CI source HEAD: `e68ffde2eebcdb58becc9d3d1ecaf195f1861e76`
- CI trigger-policy completion commit: `f563d0a524c51ff803bf8bd6b385c219bf76f3d9`
- Successful workflow run: `31069517329`
- Portable tests: 58 passed
- Native project-package tests: 9 passed
- Native Metal fixture tests: 2 passed
- Metal shader compilation: passed
- XcodeGen generation: passed
- iOS 17 arm64 Release build: passed
- Identity, version, asset, and Metal-library checks: passed
- IPA packaging and upload: passed

## Artifact

- Artifact ID: `8955148634`
- Artifact name: `After-Effects-5.0.0-unsigned-ipa`
- Artifact API digest: `sha256:f43efd3c17e018f17781f5e92cda888de6a223061e4703c136f7492659da1ea8`
- IPA SHA-256: `395e67c262fa24cb7f9b75f459ced1bf4673d6edbdc24d622d1456342f18d366`

Downloaded IPA inspection:

- executable: `Payload/AfterEffects.app/AfterEffects`;
- executable format: Mach-O 64-bit arm64;
- display name: `After Effects`;
- bundle name: `AfterEffects`;
- bundle identifier: `com.woo642778.aftereffects`;
- version: `5.0.0 (5)`;
- minimum OS: iOS 17.0;
- `Assets.car`: present;
- `Vertex_VertexRenderMetal.bundle/default.metallib`: present, 6,996 bytes.

## Current product boundary

Implemented: branded startup, one-time Telegram promotion, media inspection, thumbnail and waveform analysis, native Metal still-frame Render Lab, exact-preview PNG export, project packages, deterministic save data, Undo and Redo, journal, autosaves, recovery, media relinking, and optional media embedding.

Not implemented: continuous playback, timeline editing, real layer composition, video export, general effect stacks, keyframes, retiming, masks, tracking, AI cutout, shape or text animation, professional color or audio processing, particles, node compositing, or 3D.

## Phase 6 start gate

Phase 6 is Layers and Compositions. It must define stable composition and layer identities, media, adjustment, null, guide, camera, light, and nested-composition models, ordering and visibility rules, project commands and migrations, and one real multi-layer render vertical slice without creating a second render path. Version `6.0.0 (6)` may be published only after those gates pass.