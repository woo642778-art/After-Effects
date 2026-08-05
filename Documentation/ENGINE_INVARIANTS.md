# Engine Invariants

These rules are architectural constraints, not suggestions.

## Time

- Project, sequence, layer-local, source-media, audio-sample, and presentation time are distinct domains.
- Core time is exact and rational. Floating-point seconds are not the source of truth.
- AVFoundation `CMTime` is an adapter-boundary type, not the universal project-model type.
- Retiming maps sequence time to source time; it is not stored as a cosmetic speed label.

## Rendering

- Preview and export evaluate the same project graph and effect semantics.
- Quality tiers may alter sample count or resolution, but not the meaning of parameters.
- External rendering types such as `MTIImage`, `CIImage`, or `AVMutableComposition` do not enter persisted project models.
- GPU kernels must declare alpha, color-space, temporal-frame, precision, and edge-behavior contracts.

## Project safety

- Project writes are versioned, atomic, recoverable, and migration-tested.
- Undo/redo is command-based and does not depend on reconstructing UI state.
- Media references support relinking and do not rely solely on absolute paths.
- AI outputs are reproducible from cached results or can be converted to editable project data.

## Product truthfulness

- UI without working behavior is not a feature.
- A preview-only effect is not complete.
- A result verified on one sample is a prototype, not a production implementation.
- Failed or absent tests cannot be hidden by removing the test or lowering the gate.

## External source boundaries

- Every imported source has a repository, revision, license, purpose, and owner recorded.
- GPL code is not copied into the MIT product unless the repository's licensing strategy is explicitly changed.
- Proprietary products are behavior references only. Their source, names, presets, assets, and branding are not copied.
