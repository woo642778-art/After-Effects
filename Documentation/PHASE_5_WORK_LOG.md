# Phase 5 Work Log

## Scope

Canonical project data, session-only editing history, `.vertexproject` persistence, full pending-save transactions, immutable autosaves, bookmark sidecars, verified embedded media, non-destructive legacy import, serial app-session ownership, version 5.0.0, and unsigned IPA verification.

## Correction reason

The first Phase 5 draft implemented a writable `.aeproject` dialect with persisted history, an operation WAL, backups, mutable autosaves, and bookmark bytes in project data. That structure did not match the approved persistence contract. It is retained only as historical/legacy import evidence and is not a valid Phase 7 base.

## Test-driven correction sequence

1. Archived the pre-correction Phase 5 and Phase 6 heads and marked previous 6.0 artifacts as superseded drafts.
2. Added RED tests proving canonical JSON must exclude bookmark bytes, applied command IDs, compatibility render values, inverses, and history.
3. Introduced desired-state requests, engine-derived transitions, and `ProjectEditingSession`; verified empty history after reopen, 200-entry stack bounds, 512 recent-ID bounds, coalescing, duplicate-ID scope, and selection/Redo behavior.
4. Replaced the public filesystem product with `VertexProjectPersistence` and enforced the exact `.vertexproject` root allowlist.
5. Added durable file-I/O failure injection and a complete `Journal/pending-save.json` envelope containing independently checksummed project and manifest bytes.
6. Verified every save interruption boundary reopens to one complete pair, with explicit decisions for uncertain/older/divergent pending data.
7. Added immutable autosaves with 20-digit monotonic sequence/checksum names, duplicate suppression, corruption isolation, safe exhaustion, and eight-snapshot retention.
8. Moved bookmark bytes to sidecars and added deterministic fingerprint-verified embedded-media promotion.
9. Added internal legacy DTOs, source-tree digesting, contiguous WAL-prefix replay, non-destructive `.aeproject` conversion, per-media failure isolation, and staging cleanup.
10. Routed the application through `ProjectSessionActor`, separated canonical and legacy document types, added explicit pending-save decisions and legacy inspection UI, and compiled app-boundary tests.
11. Split app-test compilation into an independent CI job so app concurrency and document integration fail before IPA packaging.
12. Downloaded and inspected the corrected 5.0 artifact; the bundled checksum and independently computed IPA digest matched.

## Corrected verification

- Product and CI source HEAD: `e821cfa62ae2c8c42e1a9b3393553ae71f80bb68`
- Workflow run: `31111240394`
- Portable tests: 109 passed
- Native persistence tests: passed
- Native Metal fixture tests and shader compilation: passed
- iOS app session tests: compiled with `build-for-testing`
- iOS 17 arm64 Release build: passed
- Artifact ID: `8971903654`
- Artifact ZIP SHA-256: `4e2cd38972072ba2b58285744602bd2ea0a70a11aeed57a889357f73b91a6a7b`
- IPA SHA-256: `bcf72cf8105022015c468ad507f6f3a64b62c69d713b4f8ba8696a8e7fc99ed8`
- IPA size: 1,102,371 bytes

## Result

Corrected Phase 5 is complete on Draft PR #5 and remains stacked on Phase 4. The next required step is to merge this corrected state into Draft PR #6, restore canonical schema 2 and all Layers/Compositions/Metal behavior, and inspect a replacement 6.0.0 IPA before any Phase 7 source work begins.
