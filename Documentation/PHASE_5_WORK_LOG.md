# Phase 5 Work Log

## Scope

Project schema, deterministic serialization, command history, write-ahead journaling, atomic packages, autosave, recovery, migration boundaries, media relinking and embedding, real application integration, version 5.0.0, and unsigned IPA production.

## Test-driven sequence

1. Added schema and deterministic-codec tests before project types existed. CI failed on missing `ProjectDocument`, `MediaReference`, `DeterministicProjectCodec`, and `ProjectError`.
2. Implemented the portable schema, manifest, validation, timestamp codec, and SHA-256. The codec tests passed.
3. Added command, revision, duplicate-ID, Undo, Redo, and coalescing tests before implementation. CI failed on missing command and history types.
4. Implemented command preconditions, inverse operations, revision advancement, bounded history, Undo, Redo, and coalescing.
5. Added journal, replay, migration-inspection, and media-relink tests before implementation. CI failed on missing journal, migration, and relink types.
6. Implemented checksummed journal lines, trailing-line analysis, idempotent replay, future-schema inspection, sequential migration requirements, and fingerprint-only automatic relinking.
7. Added real file-system tests for atomic save, interruption, manifest matching, history persistence, journal append, autosave rotation, backup recovery, path traversal, and media embedding.
8. Implemented `VertexProjectFoundation` with package layout, durable writes, POSIX atomic rename, history and manifest files, autosaves, recovery, bookmark adapters, and embedded media.
9. A package test initially failed because in-memory `Date` values retained sub-millisecond precision while the canonical ISO-8601 format intentionally stores fixed fractional precision. Verification was changed to canonical decode/re-encode byte equality.
10. Added the application workspace and connected project creation, open, save, export, media registration, persistent Render Lab settings, Undo, Redo, autosave, recovery, relink, and embed flows.
11. The first iOS application build failed because the recovery view referenced Foundation-adapter types without importing `VertexProjectFoundation`. Adding the module import resolved the SwiftUI cascading errors.
12. Bookmark options were separated for iOS and macOS compilation boundaries, and the package document declared its `FileWrapper` sendability boundary.
13. A post-build review found that Undo and Redo changed memory before journal append. Added tests proving journal preparation runs first and that a preparation failure leaves state and stacks unchanged; updated the app to append in that callback.
14. Another review found that backup project data could be paired with a newer current history file. Added a regression test and changed backup candidates to use empty history unless a revision-matched backup history is introduced.
15. Render Lab was changed to observe project revision so Undo and Redo update visible controls as well as persistent project data.

## Final verification

- Product and CI source HEAD: `e68ffde2eebcdb58becc9d3d1ecaf195f1861e76`
- CI trigger-policy completion commit: `f563d0a524c51ff803bf8bd6b385c219bf76f3d9`
- Workflow run: `31069517329`
- Portable tests: 58 passed
- Native project package tests: 9 passed
- Native Metal tests: 2 passed
- iOS 17 arm64 Release build: passed
- Artifact ID: `8955148634`
- Artifact API digest: `sha256:f43efd3c17e018f17781f5e92cda888de6a223061e4703c136f7492659da1ea8`
- IPA SHA-256: `395e67c262fa24cb7f9b75f459ced1bf4673d6edbdc24d622d1456342f18d366`

## Result

Phase 5 is complete on Draft PR #5. The branch remains stacked on Phase 4 and is not merged. Phase 6 must begin with an approved Layers and Compositions design, project schema migration planning, and a single shared render-graph vertical slice.