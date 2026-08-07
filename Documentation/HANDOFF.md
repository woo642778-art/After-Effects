# Session Handoff

## Current correction state

Corrected Phase 5 is implemented and verified on `agent/phase-5-project-persistence`. Draft PR #5 remains open and unmerged.

The canonical contract is now:

- writable `.vertexproject` packages;
- session-only Undo/Redo and recent command IDs;
- full `Journal/pending-save.json` save transactions;
- immutable autosaves retaining eight valid unique snapshots;
- bookmark sidecars under `Bookmarks/`;
- fingerprint-verified embedded media under `Media/`;
- `.aeproject` as non-destructive import-only input;
- serial app ownership through `ProjectSessionActor`.

All earlier Phase 6 binaries remain:

**Superseded draft artifact — do not use as the Phase 7 base.**

## Read this first

1. `README.md`
2. `Documentation/PRODUCT_VISION.md`
3. `Documentation/ENGINE_INVARIANTS.md`
4. `Documentation/ROADMAP_28_PHASES.md`
5. `Documentation/SOURCE_ADOPTION_MATRIX.md`
6. `Documentation/CORE_ARCHITECTURE.md`
7. `Documentation/MEDIA_IO_ARCHITECTURE.md`
8. `Documentation/GPU_RENDER_GRAPH_ARCHITECTURE.md`
9. `Documentation/PROJECT_PERSISTENCE_ARCHITECTURE.md`
10. `Documentation/PROJECT_TEST_MATRIX.md`
11. `Documentation/PHASE_5_COMPLETION.md`
12. `Documentation/PHASE_5_WORK_LOG.md`
13. `Documentation/VERSIONING_AND_ARTIFACTS.md`
14. newest files under `docs/superpowers/specs/` and `docs/superpowers/plans/`
15. Draft PR #5, Draft PR #6, and their latest Actions runs

## Repository state

- Repository: `woo642778-art/After-Effects`
- Phase 5 branch: `agent/phase-5-project-persistence`
- Corrected Phase 5 source HEAD before documentation: `e821cfa62ae2c8c42e1a9b3393553ae71f80bb68`
- Phase 6 branch before reintegration: `agent/phase-6-layers-compositions`
- Archived pre-correction Phase 5: `agent/archive/phase-5-pre-correction` → `ec42dcd79116ff215b7913be278c554284a89f07`
- Archived pre-correction Phase 6: `agent/archive/phase-6-pre-correction` → `6aa507508ed60d8b350fe2d88b875f63627ef6d4`
- Product version: `5.0.0 (5)`
- Phase 5 schema: `1`
- Corrected Phase 6 target: `6.0.0 (6)`, schema `2`
- Display name: `After Effects`
- Bundle identifier: `com.woo642778.aftereffects`
- Minimum OS: iOS 17.0
- Artifact policy: unsigned arm64 IPA from GitHub Actions

## Corrected Phase 5 evidence

- Workflow run: `31111240394`
- Portable tests: 109 passed
- Native persistence tests: passed
- Native Metal tests and shader compilation: passed
- iOS app session tests: build-for-testing compilation passed
- iOS 17 arm64 Release build: passed
- Artifact ID: `8971903654`
- Artifact ZIP SHA-256: `4e2cd38972072ba2b58285744602bd2ea0a70a11aeed57a889357f73b91a6a7b`
- IPA SHA-256: `bcf72cf8105022015c468ad507f6f3a64b62c69d713b4f8ba8696a8e7fc99ed8`
- IPA size: 1,102,371 bytes

## Immediate next actions

1. Keep PR #5 and PR #6 Draft and unmerged.
2. Merge corrected Phase 5 into `agent/phase-6-layers-compositions` at the branch level.
3. Resolve conflicts by preserving corrected persistence APIs and Phase 6 product behavior.
4. Never restore writable `.aeproject`, persisted history, operation WAL, bookmark fields, backup files, mutable autosaves, or `VertexProjectFoundation` imports.
5. Restore canonical schema 2 composition/layer models, requests, mutations, compiler, Metal compositor, workspace, and tests.
6. Run portable, native Persistence, Metal, app-test compilation, Release build, startup, package allowlist, and forbidden-field scans.
7. Produce, download, inspect, and document the replacement `After-Effects-6.0.0-unsigned.ipa`.
8. Only then create the Phase 7 design/implementation branch.

## Do not do next

- Do not merge PR #5 or PR #6 without explicit user instruction.
- Do not start Phase 7 source work before corrected Phase 6 passes all gates.
- Do not create decorative or fake timeline/motion controls.
- Do not create separate preview and export compositors.
- Do not persist Undo/Redo, command inverses, recent command IDs, bookmarks, platform objects, or absolute sandbox paths.
- Do not claim continuous playback, video export, motion, tracking, AI, text/shape engines, professional color/audio, particles, nodes, or 3D until implemented and tested.
