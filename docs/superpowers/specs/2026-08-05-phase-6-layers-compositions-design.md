# Phase 6 Layers and Compositions Design

## Status

Approved design for Phase 6 of the After Effects/Vertex roadmap.

- Branch: `agent/phase-6-layers-compositions`
- Base branch: `agent/phase-5-project-persistence`
- Product version on successful completion: `6.0.0 (6)`
- Unsigned artifact on successful completion: `After-Effects-6.0.0-unsigned.ipa`
- Project schema after migration: `2`

Phase 6 introduces real composition and layer semantics, real multi-source GPU compositing, an adjustment-layer path, and basic nested-composition rendering. It must not create a second preview/export compositor or claim later-phase animation, timeline, 3D, or export features.

## 1. Scope

### 1.1 Real Phase 6 behavior

Phase 6 implements:

- stable composition and layer identities;
- deterministic composition and layer persistence;
- schema 1 to schema 2 migration;
- multiple media layers rendered in explicit Z-order;
- static per-layer position, anchor, independent X/Y scale, rotation, opacity, exposure, saturation, and inversion;
- real `normal`, `add`, `multiply`, and `screen` Metal blending;
- adjustment layers that affect the accumulated visible result below them;
- basic nested compositions with source start offsets and parent In/Out ranges;
- null, guide, camera, and light layer models with persistence, ordering, selection, commands, Undo, Redo, journaling, and autosave;
- a real composition workspace with exact-frame navigation and the existing persistence controls;
- one preview/output render result path;
- deterministic pixel fixtures and regression coverage;
- version `6.0.0 (6)` and an unsigned arm64 IPA after all gates pass.

### 1.2 Explicit exclusions

Phase 6 does not implement:

- continuous video playback;
- a full NLE timeline or trim-edit toolset;
- keyframes, interpolation, parenting, constraints, or motion blur;
- Time Stretch, reverse, freeze, Time Remap, or frame synthesis;
- advanced pre-composition semantics such as Collapse Transformations or Continuous Rasterization;
- camera or light influence on 2D output;
- video-file export;
- masks, tracking, AI cutout, shape rendering, text rendering, professional color management, audio processing, particles, node compositing, or 3D rendering.

Camera and light rows must be visibly marked as model-only in Phase 6. They may not be presented as active rendering controls.

## 2. Chosen architecture

### 2.1 Recommended approach

Extend the existing `VertexRender` semantic graph from one source to a multi-source DAG and compile project compositions into that graph through a new platform-neutral `VertexComposition` module.

The selected dependency direction is:

```text
VertexCore
VertexMedia
VertexProject
VertexRender
   ↑        ↑
   └─ VertexComposition
             ↑
       application adapters
             ↑
    VertexRenderMetal backend
```

More precisely:

- `VertexProject` owns persistent composition and layer values and project commands.
- `VertexComposition` depends on `VertexProject`, `VertexMedia`, and `VertexRender` and compiles a project composition at an exact time into a `RenderGraph`.
- `VertexRender` owns backend-neutral graph nodes and validation.
- `VertexRenderMetal` executes the graph.
- the app resolves package media and external security-scoped media, then supplies exact frames through the compiler interface.

`VertexRender` must not depend on `VertexProject`. This keeps the render graph reusable by future node, effect, and interchange systems.

### 2.2 Rejected approaches

#### Render every layer separately, then merge final images

Rejected because it encourages CPU/PNG round trips, complicates adjustment layers, weakens cancellation and cache semantics, and risks different preview and output paths.

#### Add a separate layer compositor beside `VertexRender`

Rejected because it creates two semantic render systems and violates the project invariant that preview and output share one graph and backend path.

## 3. Schema 2 project model

### 3.1 Project root

Schema 2 replaces composition placeholders and global Render Lab ownership with actual records.

```text
ProjectDocument
├── schemaVersion = 2
├── minimumReaderVersion
├── projectID
├── revision
├── metadata
├── settings
├── mediaRegistry
├── compositionRegistry
├── layerRegistry
├── activeCompositionID
├── selectedLayerID
├── selectedMediaID
├── legacyRenderSettings?
└── appliedCommandIDs
```

`legacyRenderSettings` is migration-only preservation data. New Phase 6 editing does not write global Render Lab state. When a schema 1 selected media item can be migrated into a media layer, the values move into that layer and `legacyRenderSettings` is `nil`. When no selected media exists, the old values remain in `legacyRenderSettings` so migration does not discard them.

### 3.2 Composition record

```text
ProjectComposition
├── id: VertexID
├── name: String
├── width: Int
├── height: Int
├── duration: RationalTime
├── frameRate: RationalTime
├── color: ColorDescriptor
├── backgroundColor: ProjectRGBAColor
└── layerIDs: [VertexID]
```

Rules:

- dimensions are in `1...8192`;
- duration is positive;
- frame rate is positive and exact;
- `layerIDs[0]` is the visually highest layer;
- the last layer ID is the visually lowest layer;
- the renderer traverses the list from last to first;
- each layer ID occurs exactly once;
- every listed layer exists and declares the same owning composition;
- a layer can belong to exactly one composition;
- background alpha may be zero for a transparent composition.

### 3.3 Layer record

```text
ProjectLayer
├── id: VertexID
├── compositionID: VertexID
├── name: String
├── source: LayerSource
├── enabled: Bool
├── locked: Bool
├── solo: Bool
├── startTime: RationalTime
├── inPoint: RationalTime
├── outPoint: RationalTime
├── transform: LayerTransform
├── blendMode: LayerBlendMode
└── operations: [LayerOperation]
```

Timing rules:

- the visible interval is `inPoint <= compositionTime < outPoint`;
- `outPoint` is exclusive;
- `0 <= inPoint < outPoint <= composition.duration`;
- `startTime` is the composition time at which the source-local timeline origin begins;
- source time is calculated as `compositionTime - startTime + sourceStartTime` for media and nested sources;
- all time values use `RationalTime`;
- locked status blocks editing but does not affect rendering.

### 3.4 Layer sources

```text
LayerSource
├── media(mediaID: VertexID, sourceStartTime: RationalTime)
├── adjustment(scope: AdjustmentScope)
├── null
├── guide
├── camera(CameraLayerSettings)
├── light(LightLayerSettings)
└── composition(compositionID: VertexID, sourceStartTime: RationalTime)
```

`AdjustmentScope` has one schema 2 value:

```text
belowAll
```

The type exists so later schemas can add explicit start/end ranges without replacing the adjustment source model.

Camera settings are portable numeric data only, such as projection identifier, focal length, clipping values, and neutral 3D vectors. Light settings are portable numeric data only, such as type, intensity, color, cone angle, and feather. Phase 6 validates and persists them but does not compile them into visible render nodes.

### 3.5 Static transform

```text
LayerTransform
├── positionX: Double
├── positionY: Double
├── anchorX: Double
├── anchorY: Double
├── scaleX: Double
├── scaleY: Double
├── rotationDegrees: Double
└── opacity: Double
```

Rules:

- position and anchor use composition-normalized top-left coordinates;
- all values must be finite;
- `scaleX` and `scaleY` must be positive;
- opacity is within `0...1`;
- rotation preserves the finite user value and is not forcibly normalized;
- Phase 7 may replace static values with animation channels without changing layer identity.

### 3.6 Layer operations

The persisted operation model is independent of Metal and contains only Phase 6-supported static operations:

```text
LayerOperation
├── exposure(stops: Double)
├── saturation(value: Double)
└── invert(enabled: Bool)
```

For media and nested layers, operations run before blending. For adjustment layers, operations run on the accumulated result below the adjustment. Adjustment-layer opacity mixes the unadjusted and fully adjusted accumulated textures.

### 3.7 Blend modes

Schema 2 stores only:

```text
normal
add
multiply
screen
```

Unsupported identifiers are rejected. Overlay, Soft Light, Difference, Darken, Lighten, Color Dodge, and Color Burn are planned extensions and require a later schema and shader expansion before they become selectable or writable.

### 3.8 Visibility and Solo

The compiler first determines layers active at the requested composition time.

- disabled layers are excluded;
- layers outside their In/Out range are excluded;
- model-only null, guide, camera, and light layers produce no pixels;
- when no active layer is solo, every active render-capable layer participates;
- when one or more active layers are solo, only active solo layers participate;
- an adjustment layer follows the same Solo filter;
- a solo adjustment with no participating result below it operates on transparency;
- locked status does not affect render inclusion.

A missing media item is an error only when its layer survives enabled, timing, and Solo filtering. Missing media on an excluded layer does not block the frame.

## 4. Schema 1 to schema 2 migration

### 4.1 Migration boundary

Future schema detection remains ahead of full writable decode. Schema 1 is migrated through ordered raw JSON migration before decoding as schema 2.

A schema 1 package is not overwritten during first migration. The application creates a new internal working package, performs migration and full validation there, and leaves the schema 1 source package unchanged. The existing app-specific `.aeproject` extension and UTI remain unchanged in Phase 6; this does not claim compatibility with Adobe `.aep` files.

### 4.2 Deterministic conversion

For every schema 1 composition placeholder:

- reuse its existing ID as the schema 2 composition ID;
- retain its non-empty name;
- assign the previous output width and height;
- assign the project frame rate;
- assign a deterministic default duration of ten seconds;
- assign the project color descriptor;
- assign a transparent background;
- start with an empty layer order.

When schema 1 contains no placeholder:

- derive one default composition ID from the project ID and constant domain string;
- create one composition named `Main Composition`;
- make it active.

When `activeCompositionID` points to a valid migrated placeholder, retain it. Otherwise select the first composition by canonical ID order.

When `selectedMediaID` is valid:

- derive a deterministic media-layer ID from project ID, active composition ID, and media ID;
- create one media layer in the active composition;
- set its source start to zero;
- set its In/Out range to the full default composition duration;
- migrate the schema 1 global transform, opacity, exposure, saturation, and inversion into the layer;
- use `normal` blend mode;
- preserve `selectedMediaID` and select the new layer.

When no selected media exists, preserve old global values in `legacyRenderSettings` and create no fake layer.

Deterministic derived IDs use SHA-256 over an explicit UTF-8 domain string and stable IDs, then map the first 16 bytes into a UUID with fixed version and variant bits. The same schema 1 bytes must always produce the same schema 2 IDs and canonical JSON bytes.

### 4.3 Migration failure

Migration fails without writing a new authoritative package when:

- source JSON is malformed;
- referenced schema 1 identities are invalid;
- generated schema 2 ownership is inconsistent;
- canonical validation fails;
- the migrated package cannot be read back with matching checksums.

The source package remains available for recovery or a future migration fix.

## 5. Project commands and history

### 5.1 Composition operations

```text
createComposition(composition, ownedLayers, insertionContext)
removeComposition(composition, ownedLayers, previousActiveID, previousSelection)
renameComposition(compositionID, before, after)
setActiveComposition(before, after)
setCompositionDimensions(compositionID, before, after)
setCompositionDuration(compositionID, before, after)
setCompositionFrameRate(compositionID, before, after)
setCompositionBackground(compositionID, before, after)
```

A composition referenced by a nested-composition layer cannot be removed. Phase 6 rejects the operation rather than performing implicit cascade deletion. Removing an unreferenced composition removes its owned layers as one reversible command payload.

### 5.2 Layer operations

```text
insertLayer(layer, compositionID, index)
removeLayer(layer, compositionID, index)
duplicateLayer(sourceLayerID, duplicateLayer, index)
renameLayer(layerID, before, after)
reorderLayer(compositionID, layerID, beforeIndex, afterIndex)
setSelectedLayer(before, after)
setLayerEnabled(layerID, before, after)
setLayerLocked(layerID, before, after)
setLayerSolo(layerID, before, after)
setLayerTiming(layerID, before, after)
setLayerTransform(layerID, before, after)
setLayerBlendMode(layerID, before, after)
setLayerSource(layerID, before, after)
setLayerOperations(layerID, before, after)
setCameraSettings(layerID, before, after)
setLightSettings(layerID, before, after)
```

Every command carries project identity, base revision, a command ID, timestamp, exact before/after state, inverse operation, and an optional merge key.

### 5.3 Preconditions and Undo/Redo

- insert requires the identity to be absent and the insertion index to be valid;
- removal requires exact record and index matches;
- reorder requires exact current index and target bounds;
- property changes require the current value to match `before`;
- nested source changes validate the full composition dependency graph;
- failed preconditions do not increment revision;
- a new normal command clears Redo history;
- transform slider changes merge by project, layer, property, and active gesture window;
- paired X/Y position edits may use one transaction merge key;
- blend-mode edits remain independent Undo entries;
- Undo of deletion restores the same identity, full record, and exact Z-order index;
- Undo/Redo journal preparation succeeds before memory, selection, order, and history mutate.

The durable order remains:

```text
validate command
→ append and synchronize journal record
→ apply command
→ increment revision
→ update Undo/Redo stacks
→ schedule autosave
```

## 6. Composition compiler

### 6.1 Public role

`VertexComposition` provides a backend-neutral asynchronous compiler.

```text
CompositionRenderRequest
├── project
├── compositionID
├── time: RationalTime
├── output descriptor
├── project revision/cache context
└── limits

CompositionFrameResolver
└── resolve(mediaID, exactSourceTime, targetSize) async throws -> PortableImage

CompositionGraphCompiler
└── compile(request, frameResolver, cancellationToken) async throws -> RenderRequest
```

The frame resolver protocol contains no URL, AVFoundation, Metal, UIKit, or SwiftUI type.

### 6.2 Exact time mapping

For a media or nested-composition layer:

```text
sourceTime = compositionTime - layer.startTime + sourceStartTime
```

The compiler does not use floating-point seconds for project time. A nested composition renders only when the parent layer is active and the calculated child time satisfies the child composition duration.

### 6.3 Z-order expansion

`Composition.layerIDs` is authoritative top-to-bottom order. Compilation starts with the composition background and traverses from the last ID to the first.

For each participating media or nested layer:

```text
source/subcomposition
→ layer operations and transform
→ composite over accumulated result
```

For an adjustment layer:

```text
accumulated result below
→ adjustment operations
→ mix by adjustment opacity
→ continue with layers above
```

Adjustment layers never affect layers above them.

### 6.4 Nested compositions

Nested compositions compile recursively into the same semantic graph. The child graph root becomes a parent layer input. The compiler maintains a composition-ID stack and rejects direct or indirect cycles, including `A → B → C → A`.

Limits:

- maximum composition dimension: `8192 × 8192`;
- maximum stored layers per composition: `256`;
- maximum nested depth: `16`;
- maximum expanded render nodes: `4096`.

Limit failures produce no partial output.

### 6.5 Request-local frame cache

The compiler caches frame resolution by:

```text
mediaID + exact source time + requested target dimensions
```

Identical requests within one composition render resolve once. The cache is discarded after the request and does not replace later persistent proxy/cache work.

### 6.6 Cancellation

Cancellation is checked:

- before resolving each media frame;
- after each asynchronous frame result;
- before descending into a nested composition;
- after compiling each layer;
- before backend submission.

A cancelled older request cannot replace a newer preview.

## 7. Render graph extension

### 7.1 Node kinds

```text
RenderNodeKind
├── source(PortableImage)
├── operations([RenderOperation])
├── composite(RenderBlendMode)
├── adjustment([RenderOperation], mix: Double)
└── output
```

The composition compiler may represent the initial transparent or colored background as a deterministic generated source image.

### 7.2 Validation

- one output node is required;
- multiple source nodes are allowed;
- source nodes have no dependencies;
- operation nodes have one dependency;
- adjustment nodes have one dependency;
- composite nodes have exactly two ordered dependencies: `[backdrop, source]`;
- output has one dependency;
- duplicate identities, missing dependencies, disconnected nodes, and cycles are rejected;
- dependency order is semantic for composite nodes and must not be sorted or normalized away;
- every supported operation and blend mode validates before backend work.

The current single-source Phase 4 validation is replaced, not bypassed.

### 7.3 Preview/output parity

```text
Project composition
→ CompositionGraphCompiler
→ RenderRequest
→ MetalRenderBackend
→ RenderResult.image
```

The preview and PNG output use the same `RenderResult.image` bytes. No preview-only compositor and no output-only compositor may be introduced.

## 8. Metal execution and blend semantics

### 8.1 Pipelines

The backend is split into explicit compute pipelines:

```text
vertexLayerKernel
vertexCompositeKernel
vertexAdjustmentKernel
```

`vertexLayerKernel` applies:

- anchor-aware transform;
- normalized position;
- independent X/Y scale;
- rotation;
- exposure;
- saturation;
- inversion;
- opacity and premultiplication.

`vertexCompositeKernel` applies the selected blend mode with alpha.

`vertexAdjustmentKernel` applies operations to the accumulated input and mixes the result using adjustment opacity.

### 8.2 Alpha representation

Internal composition textures use premultiplied alpha. Decoded straight-alpha pixels are converted before blend work. Fully transparent RGB must not contaminate output.

Given straight source color `Cs`, backdrop color `Cb`, source alpha `as`, backdrop alpha `ab`, and blend function `B(Cb, Cs)`:

```text
ao = as + ab × (1 - as)
Co-premultiplied =
    as × (1 - ab) × Cs
  + as × ab × B(Cb, Cs)
  + ab × (1 - as) × Cb
```

Blend functions:

```text
normal:   B(Cb, Cs) = Cs
add:      B(Cb, Cs) = clamp(Cb + Cs)
multiply: B(Cb, Cs) = Cb × Cs
screen:   B(Cb, Cs) = 1 - (1 - Cb) × (1 - Cs)
```

Phase 6 fixtures use deterministic Rec.709 SDR numeric inputs. The backend must preserve color metadata and perform blend math consistently, but full gamut, transfer-function, HDR, ACES, and OCIO management remains Phase 22.

### 8.3 Texture lifetime

A composition chain uses two full-size accumulator textures in ping-pong order plus transient source/layer textures. Nested results are released after their parent consumer no longer needs them. Backend execution tracks last use and reuses compatible textures instead of allocating one permanent texture per graph node.

Render metrics include:

- decoded input pixel count;
- output pixel count;
- expanded node count;
- active rendered layer count;
- estimated peak texture bytes;
- CPU encoding time;
- GPU execution time when available;
- total time.

### 8.4 Failure semantics

GPU allocation, pipeline, command-buffer, and readback failures return structured errors. The app retains the last successful preview but visibly reports the current request failure. It does not present a partial frame as successful.

## 9. Application workspace

### 9.1 View structure

```text
CompositionWorkspaceView
├── CompositionHeader
├── CompositionPreview
├── ExactFrameNavigator
├── LayerList
├── LayerInspector
└── ProjectPersistenceControls
```

The existing atomic Save, Open, Export package, Undo, Redo, autosave, relink, embed, and recovery controls remain available.

### 9.2 Composition header

Provides:

- active composition selection;
- create, duplicate, rename, and remove actions;
- dimensions, frame rate, and duration display/editing;
- explicit error when deletion is blocked by nested references.

### 9.3 Exact-frame navigator

This is not the Phase 9 NLE timeline. It provides:

- current exact frame number;
- first, previous, next, and last frame;
- direct frame-number entry;
- a simple duration scrub control whose UI Double is immediately converted to an exact frame index and never persisted as source-of-truth time.

### 9.4 Layer list

The top row is the highest Z-order. Each row shows:

- layer type;
- name;
- enabled, locked, and solo state;
- current-time activity;
- blend mode;
- missing-media status;
- a `Model only` badge for camera and light.

Dragging creates one reorder command. Add options are Media, Adjustment, Null, Guide, Camera, Light, and Nested Composition.

### 9.5 Inspector

Phase 6 inspector fields:

- name;
- enabled, locked, solo;
- Start, In, Out;
- Position X/Y;
- Anchor X/Y;
- Scale X/Y;
- Rotation;
- Opacity;
- Blend Mode;
- Exposure;
- Saturation;
- Invert;
- nested source composition and source start time;
- camera/light model data with clear no-output-impact labeling.

A locked layer cannot be changed through normal inspector controls, but it can be unlocked through its explicit lock control.

### 9.6 Media resolution

The app resolves a media layer in this order:

```text
verified embedded file
→ valid external security-scoped bookmark
→ missing-media error and relink flow
```

The app adapter requests an exact AVFoundation frame and returns `PortableImage` through `CompositionFrameResolver`.

## 10. Error model

`CompositionError` includes:

```text
missingComposition
missingLayer
missingMedia
invalidLayerOrder
invalidTimingRange
invalidTransform
unsupportedBlendMode
nestedCompositionCycle
nestingDepthExceeded
layerLimitExceeded
nodeLimitExceeded
frameResolutionFailed
graphCompilationFailed
```

Rules:

- persistent project validation and render compilation both verify ownership and cycles;
- future schema data is not decoded as writable state;
- journal failure leaves project, list order, selection, history, and preview source state unchanged;
- migration failure leaves schema 1 source data unchanged;
- deleting a layer never implicitly deletes its media registry item;
- deleting a referenced composition is rejected;
- latest-request coordination prevents stale results from publishing;
- unsupported model-only output does not silently alter pixels.

## 11. Testing strategy

### 11.1 Schema and migration

Required tests:

- deterministic schema 1 to 2 migration;
- placeholder reuse and no-placeholder default composition;
- deterministic derived composition and layer IDs;
- selected media and Render Lab value migration;
- legacy render settings preservation without selected media;
- source package unchanged on migration success and failure;
- canonical schema 2 byte equality;
- duplicate composition, layer, and layer-order identities rejected;
- ownership mismatch rejected;
- missing media/composition source reference rejected;
- direct and indirect nested cycles rejected;
- timing and transform validation.

### 11.2 Commands, journal, and history

Required tests:

- composition creation, deletion, rename, dimensions, duration, and active selection;
- referenced-composition deletion rejection;
- layer insert, remove, duplicate, rename, selection, and exact reorder;
- full-record and exact-index restoration on Undo;
- transform command coalescing;
- blend changes as independent Undo entries;
- enabled, locked, and solo commands;
- source change cycle rejection;
- journal preparation before mutation;
- failed journal preparation leaves all state unchanged;
- save/reopen restores schema 2 structure and supported history behavior;
- autosave and recovery retain layer ownership and order.

### 11.3 Compiler

Required tests:

- bottom-to-top Z-order expansion;
- enabled, timing, and Solo filtering;
- missing media only errors when participating;
- adjustment affects only accumulated layers below;
- nested exact-time offset and parent In/Out behavior;
- request-local frame deduplication;
- direct and indirect cycle refusal;
- depth 16, layer 256, and node 4096 limits;
- cancellation boundaries;
- deterministic graph and cache identity.

### 11.4 Metal pixel fixtures

Small deterministic RGBA fixtures verify:

- Normal Source Over;
- Add;
- Multiply;
- Screen;
- semitransparent edges;
- transparent RGB contamination prevention;
- position and anchor;
- independent X/Y scale;
- rotation;
- opacity;
- exposure, saturation, and inversion;
- adjustment operations and mix;
- at least two real media sources;
- nested composition output;
- preview and PNG output byte equality.

### 11.5 Regression gates

All prior exact-time, identity, color metadata, media provider, waveform, render graph, Metal, deterministic project codec, project command, journal, atomic-save, autosave, recovery, relink, embed, and product-policy tests remain green.

## 12. Delivery and verification

Phase 6 is complete only after all of the following are true:

- schema 2 and deterministic schema 1 to 2 migration pass;
- real multi-media-layer output passes pixel tests;
- Normal, Add, Multiply, and Screen pass Metal fixtures;
- adjustment layers render correctly;
- nested compositions render correctly;
- null, guide, camera, and light persist and support ordering and Undo/Redo without false rendering claims;
- project save, journal, autosave, recovery, relink, and embed regression tests pass;
- Linux portable Swift tests pass;
- native macOS Foundation project tests pass;
- native Metal tests and shader compilation pass;
- iOS 17 generic-device Release build passes;
- product identity, version `6.0.0 (6)`, arm64 architecture, app assets, and compiled Metal resources are inspected;
- `After-Effects-6.0.0-unsigned.ipa` is downloaded and its SHA-256 is recorded;
- completion, work-log, versioning, README, and handoff documents state both implemented and excluded behavior;
- Draft PR #6 remains stacked on Phase 5 and is not merged automatically.

## 13. Implementation principles

- TDD is required for schema, commands, compiler, and blend behavior.
- No decorative layer UI may land before its command and render semantics exist.
- Preview and output may not diverge.
- Exact `RationalTime`, deterministic persistence, non-destructive recovery, source-license traceability, and honest status cannot be weakened.
- Project data may not persist AVFoundation, Metal, UIKit, SwiftUI, security-scoped URL, file-descriptor, or absolute sandbox-path objects.
- New external source code is not required for this phase. Apple APIs remain adapter boundaries, and current audited third-party candidates remain unlinked unless separately reviewed and approved.
