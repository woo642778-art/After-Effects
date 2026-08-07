# Composition Test Matrix

## Final verified run

- Product source HEAD: `852d6fde6157134e6ce46adb365c5f4474528215`
- Workflow run: `31081513272`
- Artifact ID: `8959725912`

## Automated coverage

| Area | Verified behavior |
|---|---|
| Schema 2 | canonical registry ordering, authoritative Z-order preservation, ownership, source identity, timing, transforms, model-only restrictions, nested cycles |
| Schema migration | deterministic schema 1→2 bytes and IDs, selected-media conversion, legacy-value preservation, non-destructive package migration, future-schema no-rewrite |
| Commands | composition and layer create/remove/rename/reorder/property operations, exact inverse payloads, locked-layer preconditions, nested-reference deletion refusal |
| Undo/Redo | exact index restoration, command coalescing, Redo invalidation, journal-before-mutation failure atomicity |
| Persistence | schema 2 save/reopen, checksums, journal replay, autosave rotation, backup recovery, separate recovered package, relink and embedding regressions |
| Render DAG | multiple sources, ordered composite dependencies, local operations, adjustment nodes, cache context, disconnected-node and cycle refusal |
| Composition compiler | exact bottom-to-top expansion, timing, Solo, disabled layers, negative source time, missing participating media, frame deduplication, adjustment placement, nested recursion and limits |
| Metal pixels | Normal, Add, Multiply, Screen, semitransparent alpha, transparent-RGB isolation, adjustment exposure, parameter layout |
| Nested end-to-end | `ProjectDocument → CompositionGraphCompiler → RenderGraph → MetalRenderBackend → PNG` produces the expected deterministic pixel |
| Product | XcodeGen generation, iOS 17 unsigned Release build, arm64 binary, app identity, asset catalog, compiled Metal library, IPA packaging |

## Final counts

- Portable Swift tests: **81 passed**
- Native Metal target: **8 passed**
- Native project-package target: **11 passed**
- Native composition-compiler target: **5 passed**
- Independent Metal source compilation: passed
- iOS 17 generic-device Release build: passed

The specialized native target counts overlap with the full macOS package test discovery. They are listed as the explicit workflow filters used by the final verification run, not summed into one unique global total.

## Pixel expectations

The deterministic fixtures verify:

- 50% red over opaque blue with Normal produces approximately RGBA `128, 0, 128, 255`;
- opaque Add, Multiply, and Screen produce frozen one-byte-tolerance fixtures;
- fully transparent red cannot alter an opaque blue backdrop;
- exposure +1 on 25% gray through a fully mixed Adjustment Layer produces approximately 50% gray;
- a nested child composition containing a decoded red source renders an opaque red parent result.

## Not verified by automation

The following require later manual or device-specific validation:

- installation and signing on a physical iPhone or iPad;
- long-duration editing sessions and memory-pressure termination;
- large real-world projects near all resource limits;
- external document-provider bookmark behavior across device restart and provider account changes;
- interactive responsiveness with many independently decoded high-resolution movie layers;
- continuous playback, video export, and later-phase systems that are not implemented.
