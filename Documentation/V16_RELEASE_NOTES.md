# Vertex2 16.0.0

Vertex2 16 expands the effects system, adds advanced deterministic pre-compose operations, reduces interactive effect-control stalls, and introduces persistent offline Focus Music for long editing sessions while preserving the full-quality preview/export contract.

## Effects scale and compatibility browser

- Effects & Presets now exposes the complete 1,568-entry effects/plugins/tools index derived from the verified encyclopedia supplied for the project.
- Indexed entries retain product and category grouping and are searchable by effect, category, or product name.
- Vertex2 never claims an indexed commercial/plugin entry as implemented unless it maps to a real Vertex-owned implementation.
- Implemented entries are explicitly marked `NATIVE` or `AI`; reference-only items are marked `INDEXED`, `EXT`, `SCRIPT`, or `LEGACY` as applicable.
- V16 expands the actual executable effect set to 25 effects: 21 native Core Image-backed effects and 4 existing on-device AI effects.

## Native effects added in V16

- Fast Box Blur
- Directional Blur
- Median
- Noise Reduction
- Vibrance
- Gamma Adjust
- Highlights & Shadows
- Sepia Tone
- Posterize
- Mosaic
- Find Edges
- Glow
- Vignette
- Cartoon
- Twirl

These effects use the same ordered project effect stack and shared preview/export resolver contract as existing effects.

## Interactive performance

- Native effects reuse worker-thread Core Image contexts instead of rebuilding Core Image/Metal state for each slider sample or frame.
- Continuous scalar controls keep an immediate local UI draft while project mutations and preview renders are coalesced.
- Spatially expensive blur/noise/glow/distortion filters use a lower adaptive intermediate preview cadence; cheap color transforms retain a higher cadence.
- The final slider value is always committed when editing ends, so export and settled preview state remain exact and full quality.

## Focus Music

- Added six original Vertex2-generated ambient/lo-fi instrumental tracks: Quiet Desk, Midnight Render, Rainy Timeline, Warm Keyframes, Soft Circuit, and Deep Focus.
- Focus Music is offline and does not require streaming, a server, or copyrighted commercial songs.
- The player lives at app scope, so closing its popover or changing editor tools/workspaces does not stop playback.
- Users can choose tracks, play/pause, move to previous/next tracks, and adjust a dedicated Focus Music volume.
- Track choice and volume persist between launches; playback itself defaults to off after a fresh launch so the app never starts making sound unexpectedly.
- Music is generated once into PCM and looped by the audio player, avoiding a continuous synthesis workload during editing.
- Focus Music is deliberately separate from project/timeline audio and is never included in project exports.

## Advanced pre-compose

- Added deterministic pre-compose planning and project commands for selected layer groups.
- Layer ordering, source references, timing, and new composition identity are validated before mutation.
- Pre-compose operations participate in the same project command/undo architecture rather than bypassing project state.

## Compatibility

- Project schema remains 5.
- Existing V15 projects remain compatible.
- Bundle ID remains `com.woo642778.aftereffects`.
- iPad-only target, minimum iOS/iPadOS 17.0.

## Build

- Version: 16.0.0
- Build: 16
- Bundle ID: `com.woo642778.aftereffects`
- iPad only
- Minimum iOS/iPadOS: 17.0
- Unsigned IPA; installation requires signing or re-signing.
