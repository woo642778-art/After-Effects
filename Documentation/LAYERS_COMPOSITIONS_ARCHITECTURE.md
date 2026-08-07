# Layers and Compositions Architecture

## Scope

Phase 6 introduces the first real multi-layer composition system. It adds deterministic schema 2 project ownership, a platform-neutral composition compiler, an ordered multi-source render DAG, and native Metal composition. Preview and PNG output consume the same `RenderResult.image` bytes.

## Module boundaries

```text
VertexProject
  schema 2 composition/layer values
  migration, validation, commands, Undo/Redo

VertexComposition
  exact-time visibility and Solo rules
  media-frame resolution protocol
  nested-composition expansion
  ProjectDocument → RenderGraph compilation

VertexRender
  backend-neutral source, operation, composite,
  adjustment, and output nodes

VertexRenderMetal
  node-by-node DAG execution
  texture reuse and lifetime tracking
  premultiplied-alpha GPU kernels

App / VertexProjectFoundation
  package migration and recovery
  security-scoped media URL resolution
  AVFoundation exact-frame decoding
  SwiftUI workspace and latest-request publishing
```

`VertexRender` does not depend on `VertexProject`. `VertexComposition` is the adapter between persistent project semantics and the reusable render graph.

## Schema 2 ownership

`ProjectDocument` stores sorted media, composition, and layer registries. `ProjectComposition.layerIDs` is not sorted because it is the authoritative top-to-bottom Z-order.

Each layer:

- has one stable identity;
- belongs to exactly one composition;
- appears exactly once in its owner's `layerIDs`;
- uses exact `RationalTime` for Start, In, Out, and source offsets;
- validates source identities, timing, transform values, blend mode, and layer-type restrictions.

New projects contain one active empty `Main Composition`. Schema 1 projects migrate into separate schema 2 working packages. Valid schema 1 journal records are replayed before migration; incompatible schema 1 Undo/Redo and journal state are reset in the migrated package.

## Layer types

Phase 6 renders:

- media layers;
- adjustment layers;
- nested compositions.

Null, Guide, Camera, and Light are durable model-only records. They support selection, ordering, commands, Undo/Redo, journaling, autosave, and recovery, but produce no pixels. Camera and Light controls are visibly labeled `Model only`.

## Visibility and timing

A layer participates when:

```text
enabled
and inPoint <= compositionTime < outPoint
and Solo filtering includes it
```

If any active layer is Solo, only active Solo layers participate. Locked state affects editing, not rendering. Missing media is an error only when the corresponding media layer survives these filters.

Media and nested source time is:

```text
sourceTime = compositionTime - layer.startTime + sourceStartTime
```

Negative source time and nested time at or beyond child duration produce transparency. Project time is never persisted as floating-point seconds.

## Z-order and adjustment layers

Composition order is stored top-to-bottom and compiled bottom-to-top. A media or nested layer is transformed and processed before it is composited over the current accumulator.

An Adjustment Layer processes only the accumulated result below it. Its opacity controls the mix between the unadjusted and adjusted accumulator. Layers above it remain unaffected.

## Nested compositions

Nested compositions recursively expand into the same render DAG. Direct and indirect cycles are rejected in persistent validation and during compilation. Phase 6 supports parent In/Out ranges and child source-start offsets. Time Stretch, Time Remap, Collapse Transformations, and Continuous Rasterization remain later-phase work.

Limits:

- dimensions: 8192 × 8192 maximum;
- stored layers: 256 per composition;
- nested depth: 16;
- expanded render nodes: 4096.

## Render DAG

Node kinds:

```text
source(PortableImage)
solidColor(RenderRGBAColor)
operations([RenderOperation])
composite(RenderBlendMode)
adjustment([RenderOperation], mix)
output
```

Composite dependencies are ordered `[backdrop, source]`. The graph rejects duplicate IDs, missing dependencies, wrong node arity, disconnected nodes, and cycles. Operations are node-local; the previous global `flattenedOperations()` execution path is no longer used by the Metal backend.

## Metal semantics

Internal textures use premultiplied alpha. Straight decoded input is normalized before composition. Phase 6 implements:

- Normal Source Over;
- Add;
- Multiply;
- Screen.

The shader prevents RGB values under fully transparent alpha from contaminating the result. Layer kernels implement anchor-aware position, independent X/Y scale, rotation, exposure, saturation, inversion, and opacity. Adjustment kernels apply exposure, saturation, inversion, and mix.

The executor evaluates topological nodes, tracks consumer counts, and returns compatible textures to a bounded pool after last use. Metrics include expanded nodes, rendered layers, decoded pixels, output pixels, estimated peak texture bytes, CPU time, GPU time when available, and total time.

## App workspace

The Phase 6 workspace provides:

- composition creation, duplication, selection, rename, size, duration, and deletion;
- explicit deletion-block reasons for nested references or the final composition;
- exact first/previous/next/last/direct-frame navigation and integer-frame scrubbing;
- actual GPU preview with last-success retention;
- ordered layer list with Enabled, Lock, Solo, activity, blend, missing-media, and model-only state;
- layer creation, duplication, deletion, and reorder;
- transform, timing, blend, exposure, saturation, inversion, nested source, camera model, and light model controls;
- package Open, Save, Export, Undo, Redo, autosave, recovery, relink, and embed flows;
- PNG export from the exact bytes displayed in preview.

## Explicit exclusions

Phase 6 does not implement continuous playback, a full NLE timeline, keyframes, parenting, motion blur, retiming, advanced pre-composition, visible Camera/Light rendering, video-file export, masks, tracking, AI cutout, shape/text engines, professional color/audio, particles, node compositing, or 3D rendering.
