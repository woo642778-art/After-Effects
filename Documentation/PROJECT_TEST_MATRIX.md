# Project Persistence Test Matrix

## Portable Swift suite

The final Linux Swift 6.0.3 run executed 58 tests with zero failures.

### Project schema and codec

- equal logical projects encode to identical bytes;
- registry insertion order does not affect bytes;
- deterministic SHA-256 is 64 lowercase hexadecimal characters;
- non-finite render values are rejected;
- future schemas are rejected before writable decoding;
- project timestamps use canonical UTC encoding.

### Commands and history

- command application increments revision exactly once;
- duplicate command IDs are rejected;
- stale base revisions are rejected;
- Undo and Redo restore Render Lab values;
- compatible slider commands coalesce into one Undo entry;
- a new normal command clears Redo history;
- Undo journal preparation occurs before state mutation;
- a failed journal preparation leaves project and history unchanged.

### Journal and compatibility

- journal records are independently checksummed;
- deterministic lines decode and replay;
- replay is idempotent for already-applied commands;
- a truncated final line is excluded while complete preceding lines survive;
- sequence gaps stop replay;
- future project metadata can be inspected without writable decode;
- a missing sequential migration link is rejected.

### Media relinking

- filename alone is not accepted as a strong relink;
- one matching fingerprint produces automatic relink;
- multiple matching fingerprints require user selection;
- no candidates report missing media.

### File-system package behavior

- package paths cannot use absolute paths or parent traversal;
- package creation produces matching project, manifest, checksum, and history;
- an injected failure after temporary project write preserves the prior current project;
- persisted history restores an Undo operation after reload;
- journal append produces one complete durable line;
- autosave retention is bounded to current, previous, and two hourly snapshots;
- a corrupt current project recovers from a valid backup into a separate package;
- backup recovery does not reuse history from a newer revision;
- embedded media remains resolvable after the external source is deleted.

### Existing regression coverage

The same run also passed all prior exact-time, identity, dependency, color, media-provider, waveform, render-graph, cache-key, cancellation, preview/output-parity, and milestone-policy tests.

## Native macOS suite

The final macOS job ran `VertexProjectFoundationTests` separately and passed 9 project-package tests. This verifies the Foundation implementation on an Apple platform in addition to the Linux file-system run.

The same job passed 2 native Metal fixture tests and compiled the Metal shader source independently.

## iOS build and product checks

The final GitHub Actions run passed:

- XcodeGen project generation;
- supplied Ae icon asset generation;
- iOS 17 generic-device Release compilation;
- unsigned arm64 application build;
- display name `After Effects`;
- bundle identifier `com.woo642778.aftereffects`;
- version `5.0.0 (5)`;
- compiled `Assets.car` presence;
- packaged `Vertex_VertexRenderMetal.bundle/default.metallib` presence;
- unsigned IPA packaging and artifact upload.

## Final evidence

- Product and CI source HEAD: `e68ffde2eebcdb58becc9d3d1ecaf195f1861e76`
- Successful workflow run: `31069517329`
- Portable tests: 58 passed
- Native project-package tests: 9 passed
- Native Metal fixture tests: 2 passed
- Artifact ID: `8955148634`
- Artifact ZIP SHA-256: `f43efd3c17e018f17781f5e92cda888de6a223061e4703c136f7492659da1ea8`
- Extracted IPA SHA-256: `c938b34ed987acd03610984b8592da74009f8e03297ee2c9556152e6b0cd33d2`
- IPA size: 884,969 bytes

## Unverified environment

No physical iPhone or iPad installation, signing, long-duration field test, external-provider document round trip, or manual recovery UI session was performed. The IPA remains unsigned.