# Vertex2 V15 Effects Architecture v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated effect metadata with one typed descriptor registry, add deterministic versioned presets, preserve the existing render/animation contract, and produce a verified Vertex2 15.0.0 unsigned iPad IPA.

**Architecture:** Keep `ProjectEffect`'s persisted shape stable while moving defaults and parameter rules into a new descriptor registry in `VertexProject`. Derive the app effect catalog and control metadata from the registry. Add a schema-2 preset codec with schema-1 migration, then validate through portable tests and the existing iPad Release pipeline adapted to V15.

**Tech Stack:** Swift 6, SwiftUI, VertexProject, Core Image/Metal existing render path, Core ML existing AI pipeline, XcodeGen, GitHub Actions.

## Global Constraints

- Bundle identifier remains `com.woo642778.aftereffects`.
- Minimum iOS/iPadOS remains 17.0.
- Target family remains iPad-only (`2`).
- Existing V14 project effect JSON remains compatible.
- Effect ordering, animation references, native preview/export parity, and AI bake behavior must not regress.
- No placeholder AI model may enter the release IPA.
- Final version/build is exactly `15.0.0 (15)`.

---

### Task 1: Typed descriptor registry and preset format

**Files:**
- Create: `Sources/VertexProject/ProjectEffectDescriptor.swift`
- Create: `Tests/VertexProjectTests/Phase15EffectDescriptorTests.swift`

**Interfaces:**
- Produces `ProjectEffectDescriptorRegistry.all` and `descriptor(for:)`.
- Produces `ProjectEffectPreset` and `ProjectEffectPresetCodec`.

- [ ] Define categories, execution modes, parameter domains, parameter descriptors, and effect descriptors for all ten implemented effects.
- [ ] Define deterministic schema-2 preset encoding and schema-1 migration.
- [ ] Add tests for registry completeness, typed parameter metadata, deterministic round trip, fresh effect identity, and legacy migration.

### Task 2: Route the project model through descriptors

**Files:**
- Modify: `Sources/VertexProject/ProjectEffect.swift`
- Test: `Tests/VertexProjectTests/ProjectEffectTests.swift`

**Interfaces:**
- Consumes `ProjectEffectDescriptorRegistry`.
- Preserves public `ProjectEffect` Codable layout and existing parameter-ID constants.

- [ ] Make default effects from descriptor defaults.
- [ ] Validate version, exact parameter identity set, type/range/options, and cross-parameter rules through descriptor metadata.
- [ ] Run portable effect tests and keep existing effect ordering/animation checks green.

### Task 3: Route app catalog and controls through descriptors

**Files:**
- Modify: `App/EffectsAndPresetsView.swift`
- Modify: `App/EffectControlsView.swift`
- Modify: `App/AIEffectControlsView.swift`
- Modify: `Tests/VertexAppTests/EffectsAndPresetsCatalogTests.swift`

**Interfaces:**
- Catalog consumes registry display/category/search metadata.
- Parameter controls consume descriptor label/range/options metadata.

- [ ] Remove duplicated catalog strings and parameter range/option switch tables.
- [ ] Keep SF Symbol selection in the app presentation layer.
- [ ] Verify catalog order/search behavior remains stable and all entries map one-to-one to descriptors.

### Task 4: Version, release notes, and V15 qualification

**Files:**
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `.github/workflows/phase12-test-ipa.yml`
- Create: `Documentation/V15_RELEASE_NOTES.md`

**Interfaces:**
- Produces `Vertex2-15.0.0-unsigned.ipa`, checksum, build logs, and GitHub Release `v15.0.0`.

- [ ] Set app version/build to `15.0.0 (15)` while retaining the current project schema.
- [ ] Make the release workflow trigger on `agent/phase15-effects-architecture` and verify descriptor/preset integration.
- [ ] Run portable Swift tests, AI audits/model preparation, XcodeGen, unsigned arm64 iPad Release build, IPA audit, Actions artifact upload, and GitHub Release publication.
- [ ] Download the Actions artifact and independently verify the IPA SHA-256 before handoff.
