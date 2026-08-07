# Project Persistence Test Matrix

## Corrected Phase 5 verification

The corrected Phase 5 source HEAD `e821cfa62ae2c8c42e1a9b3393553ae71f80bb68` passed GitHub Actions run `31111240394`.

### Portable Swift 6.0.3 suite

The Linux run completed **109 tests with zero failures**.

Canonical model and session coverage includes:

- deterministic project bytes and registry ordering;
- absence of bookmark bytes, applied command IDs, legacy compatibility values, history, command inverses, and persistence state from canonical JSON;
- portable `MediaLocator` fields only;
- desired-state request validation and exact forward/inverse transition derivation;
- one revision increment per transition and stale-revision rejection;
- empty history and recent-ID state after open/reopen;
- 200-entry Undo/Redo bounds and 512 recent-command-ID bound;
- duplicate command rejection within one session and acceptance in a new session;
- continuous-edit coalescing and Redo preservation across workspace selection.

Package and transaction coverage includes:

- `.vertexproject` extension enforcement;
- exact root allowlist and rejection of legacy/unknown entries;
- path-containment checks;
- durable write, file synchronization, atomic promotion, directory synchronization, and exact injected failures;
- matching project/manifest creation and replacement;
- independent pending-envelope checksums;
- six save-boundary interruption cases reopening to one complete verified pair;
- automatic completion only for a proven valid newer/partial candidate;
- explicit decision for corrupt, uncertain, older, or divergent pending data.

Autosave, bookmark, and media coverage includes:

- immutable 20-digit sequence/checksum autosave names;
- duplicate suppression, corruption isolation, sequence exhaustion, and retention of eight valid unique snapshots;
- no history, command, inverse, recent-ID, or bookmark state in autosaves;
- lowercase bookmark-sidecar names, atomic replacement, stale refresh, missing/corrupt sidecar isolation;
- deterministic sanitized embedded-media names, traversal rejection, pre/post fingerprint checks, collision rejection, tamper detection, and independence from external originals.

Legacy import coverage includes:

- source-tree digest equality before and after inspection/conversion;
- preserved project/composition/media IDs and timestamps;
- valid contiguous journal-prefix replay with checksum/gap/unknown-command/invalid-transition stopping rules;
- truncated final-line isolation;
- discarded persisted Undo/Redo, backup, and mutable autosave state;
- per-media bookmark failure isolation;
- verified embedded-media copy;
- deterministic repeated conversion bytes and failed-staging cleanup.

All prior exact-time, identity, dependency, color, media-provider, waveform, render-graph, cache-key, cancellation, Metal fixture, preview/output-parity, and milestone-policy tests also remained active.

## Apple-platform and app verification

The macOS job passed native `VertexProjectPersistenceTests`, native Metal fixture tests, and independent Metal shader compilation.

The iOS app-test job generated the Xcode project and compiled the app plus `Tests/VertexAppTests` with `build-for-testing`. Those tests cover canonical and legacy UTTypes, serial session operations, Undo/Redo, pending-decision handling, and concurrent request ordering at the app boundary.

The Release job passed:

- XcodeGen and supplied icon generation;
- iOS 17 generic-device unsigned Release compilation;
- arm64 executable verification;
- display name `After Effects`;
- bundle identifier `com.woo642778.aftereffects`;
- version `5.0.0 (5)`;
- `Assets.car` and packaged Metal library checks;
- unsigned IPA packaging and artifact upload.

## Artifact evidence

- Workflow run: `31111240394`
- Artifact ID: `8971903654`
- Artifact name: `After-Effects-5.0.0-unsigned-ipa`
- Artifact ZIP SHA-256: `4e2cd38972072ba2b58285744602bd2ea0a70a11aeed57a889357f73b91a6a7b`
- IPA SHA-256: `bcf72cf8105022015c468ad507f6f3a64b62c69d713b4f8ba8696a8e7fc99ed8`
- IPA size: `1,102,371` bytes
- Executable: Mach-O 64-bit arm64
- Minimum OS: iOS 17.0
- `Assets.car`: 152,879 bytes
- `Vertex_VertexRenderMetal.bundle/default.metallib`: 6,996 bytes

The ZIP-bundled checksum file reports the same IPA SHA-256.

## Unverified environment

No physical-device installation, signing, long-duration field test, external-provider document round trip, or manual destructive recovery exercise was performed. The IPA is unsigned. This corrected 5.0 artifact verifies Phase 5 only; it is not the final Phase 7 base until corrected Phase 6 is reintegrated and a replacement 6.0 artifact is inspected.
