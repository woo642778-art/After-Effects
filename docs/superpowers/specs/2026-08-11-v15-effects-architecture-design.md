# Vertex2 V15 Effects Architecture v2 Design

## Goal

Turn the existing V14 effect stack into a descriptor-driven architecture without changing effect ordering, animation semantics, native preview/export rendering, AI bake behavior, or existing project JSON compatibility. Add a deterministic, versioned effect-preset format and ship Vertex2 15.0.0 (15) as an iPad-only unsigned IPA.

## Architecture

`VertexProject` owns all effect metadata. A new `ProjectEffectDescriptorRegistry` is the single source of truth for effect display names, categories, search keywords, descriptions, execution mode, parameter labels, parameter types, allowed ranges/options, default values, and animatability. `ProjectEffect.makeDefault` and `ProjectEffect.validated` consume this registry instead of maintaining independent switch tables.

The persisted `ProjectEffect` shape remains unchanged (`id`, `type`, `version`, `enabled`, `parameters`), so existing V14 project files remain readable without a project-schema bump. Cross-parameter validation such as Depth Map near < far remains enforced at the model boundary.

`ProjectEffectPreset` is a separate portable interchange object. The current preset schema is version 2. The decoder accepts legacy schema 1 payloads that use `type` and omit `effectVersion`, upgrades them in memory, and the encoder always emits canonical schema 2 JSON with sorted keys. Applying a preset creates a fresh effect identity while preserving descriptor-validated parameter values.

## UI integration

`EffectsAndPresetsView` builds its catalog from `ProjectEffectDescriptorRegistry.all`; it no longer duplicates names, categories, keywords, or descriptions. `EffectControlsView` uses descriptor display names. `AIEffectControlsView` uses parameter descriptors for labels, slider ranges, integer ranges, and text options, eliminating UI-local parameter rules.

SF Symbols remain UI-owned because they are presentation details rather than project metadata.

## Compatibility and rendering invariants

- Existing `ProjectEffect` Codable layout is unchanged.
- Effect array order remains authoritative.
- Existing animation property references still target effect ID + parameter ID + value kind.
- Native effects continue through `NativeFrameEffectProcessor` and the shared composition preview/export path.
- AI effects retain the existing bake/extract pipeline.
- No commercial or unavailable effect is added to the catalog.
- Bundle identifier remains `com.woo642778.aftereffects`.
- Target remains iPad-only, minimum iOS/iPadOS 17.0.

## Validation

Portable tests cover descriptor completeness, default construction, strict typed validation, deterministic preset round trips, schema-1 preset migration, catalog metadata derivation, effect order persistence, and animation compatibility. Release qualification additionally prepares pinned AI resources, builds the unsigned arm64 iPad Release app, audits bundle identity/device family/signing state, packages the IPA, writes SHA-256, uploads the Actions artifact, and publishes `v15.0.0`.
