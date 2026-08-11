# Vertex2 15.0.0

Vertex2 15 introduces Effects Architecture v2 while preserving the existing V14 render, animation, and project compatibility contracts.

## Effects Architecture v2

- One typed `ProjectEffectDescriptorRegistry` now owns metadata for every implemented native and AI effect.
- Parameter descriptors define authoritative labels, default values, scalar/integer ranges, text options, and animation capability.
- `ProjectEffect.makeDefault` and strict project validation now consume the same descriptors used by the editor UI.
- Effects & Presets search derives names, categories, keywords, and descriptions from the shared registry instead of UI-local tables.
- Effect Controls derive slider ranges, integer bounds, picker options, and parameter labels from descriptors.
- Existing stack order and effect IDs remain authoritative, so animation references and preview/export ordering semantics are unchanged.

## Versioned effect presets

- Added deterministic `ProjectEffectPreset` schema 2 serialization with sorted-key JSON output.
- Added fail-closed future-version handling.
- Added schema 1 migration for legacy preset payloads using `type` and no explicit effect version.
- Applying a preset creates a fresh effect identity while retaining descriptor-validated settings.

## Compatibility

- Existing persisted `ProjectEffect` layout is unchanged.
- Project schema remains 5; V14 project files remain compatible with the V15 effect model.
- Native pixel effects continue through the shared preview/export processor.
- AI effects retain the existing on-device bake/extract pipeline and pinned model resources.

## Build

- Version: 15.0.0
- Build: 15
- Bundle ID: `com.woo642778.aftereffects`
- iPad only
- Minimum iOS/iPadOS: 17.0
- Unsigned IPA; installation requires signing or re-signing.
