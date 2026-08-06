# Phase 6 Layers and Compositions Design

## Status

Approved design for Phase 6 of the After Effects/Vertex roadmap.

- Branch: `agent/phase-6-layers-compositions`
- Base: `agent/phase-5-project-persistence`
- Successful product version: `6.0.0 (6)`
- Successful unsigned artifact: `After-Effects-6.0.0-unsigned.ipa`
- Project schema after migration: `2`

Phase 6 adds real composition and layer semantics, real multi-source GPU compositing, adjustment layers, and basic nested-composition rendering. It does not add a second preview/export path and does not claim later-phase timeline, animation, 3D, or video-export behavior.

## 1. Accepted scope

### 1.1 Real behavior

Phase 6 implements:

- stable composition and layer identities;
- deterministic schema 2 persistence;
- non-destructive schema 1 to schema 2 migration;
- multiple media layers rendered in explicit Z-order;
- static position, anchor, independent X/Y scale, rotation, opacity, exposure, saturation, and inversion;
- real Metal `normal`, `add`, `multiply`, and `screen` blending;
- adjustment layers affecting all participating layers below them;
- nested compositions with parent In/Out ranges and source-start offsets;
- null, guide, camera, and light records with persistence, ordering, commands, Undo, Redo, journaling, autosave, and recovery;
- an exact-frame composition workspace;
- one semantic render request used by preview and PNG output;
- deterministic compiler and pixel tests;
- a verified `6.0.0 (6)` unsigned arm64 IPA after every gate passes.

### 1.2 Exclusions

Phase 6 does not implement:

- continuous playback;
- a full NLE timeline or trim tools;
- keyframes, interpolation, parenting, constraints, or motion blur;
- Time Stretch, reverse, freeze, Time Remap, or frame synthesis;
- Collapse Transformations, Continuous Rasterization, or advanced pre-composition behavior;
- visible camera or light rendering;
- video-file export;
- masks, tracking, AI cutout, shape rendering, text rendering, professional color management, audio processing, particles, node compositing, or 3D rendering.

Camera and light rows are marked `Model only` and must not appear to affect Phase 6 output.

## 2. Architecture

### 2.1 Selected approach

The existing `VertexRender` graph becomes a multi-source DAG. A new platform-neutral `VertexComposition` module compiles persistent project data into that graph.

```text
VertexCore        VertexMedia
    ↑                 ↑
VertexProject      VertexRender
      \              /
       VertexComposition
               ↑
        application adapters
               ↓
       VertexRenderMetal
```

Dependency rules:

- `VertexProject` owns persistent composition/layer values and project commands.
- `VertexComposition` depends on `VertexProject`, `VertexMedia`, and `VertexRender`.
- `VertexRender` owns backend-neutral graph values and validation and does not depend on `VertexProject`.
- `VertexRenderMetal` executes `VertexRender` requests.
- the app resolves package or external media and implements the frame-resolver adapter.

This preserves one preview/output semantic path and keeps the graph reusable for future effect and node systems.

### 2.2 Rejected approaches

Rendering every layer separately and merging final PNG/CPU buffers is rejected because it creates avoidable round trips, weakens cancellation and cache semantics, and complicates adjustment layers.

A separate layer compositor beside `VertexRender` is rejected because it would create two render systems.

## 3. Schema 2 model

### 3.1 Project root

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

`legacyRenderSettings` exists only to preserve schema 1 global Render Lab values when no selected media can be converted into a layer. New Phase 6 edits do not write global Render Lab state.

Canonical serialization sorts `mediaRegistry`, `compositionRegistry`, `layerRegistry`, and `appliedCommandIDs` by stable ID. It never sorts `ProjectComposition.layerIDs`; that array is the authoritative Z-order. Authoritative JSON remains UTF-8, sorted-key, non-pretty-printed, finite-number-only, and free of platform or GPU objects.

### 3.2 Composition

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

- width and height are each `1...8192`;
- duration and frame rate are positive exact values;
- `layerIDs[0]` is the visually highest layer;
- the final ID is the visually lowest layer;
- rendering traverses from the final ID toward index zero;
- IDs are unique and each referenced layer exists;
- every referenced layer declares this composition as owner;
- every layer belongs to exactly one composition;
- background RGBA components are finite and within `0...1`.

### 3.3 Layer

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

- a layer participates only when `inPoint <= compositionTime < outPoint`;
- `outPoint` is exclusive;
- `0 <= inPoint < outPoint <= composition.duration`;
- `startTime` defines the composition time corresponding to source-local zero before source-start offset;
- all project time uses `RationalTime`;
- locked status affects editing only, not rendering.

### 3.4 Layer sources

```text
LayerSource
├── media(mediaID, sourceStartTime)
├── adjustment(scope)
├── null
├── guide
├── camera(settings)
├── light(settings)
└── composition(compositionID, sourceStartTime)
```

Schema 2 has one adjustment scope: `belowAll`.

Media and nested-composition source time is:

```text
sourceTime = compositionTime - startTime + sourceStartTime
```

A negative source time produces transparency without resolving a frame. A nested source time at or beyond child duration also produces transparency. The media frame adapter returns either a frame or an explicit valid out-of-range transparent result; I/O, decode, or missing-media failures remain errors.

### 3.5 Exact camera and light records

Camera settings are model-only and contain exactly:

```text
CameraLayerSettings
├── projection: perspective
├── focalLengthMillimeters: Double
├── nearClip: Double
├── farClip: Double
├── positionX/Y/Z: Double
└── pointOfInterestX/Y/Z: Double
```

Validation:

- projection has only `perspective` in schema 2;
- focal length and near clip are positive;
- far clip is greater than near clip;
- all values are finite.

Light settings contain exactly:

```text
LightLayerSettings
├── kind: point | directional | spot
├── color: ProjectRGBAColor
├── intensity: Double
├── positionX/Y/Z: Double
├── directionX/Y/Z: Double
├── coneAngleDegrees: Double
└── coneFeather: Double
```

Validation:

- intensity is nonnegative;
- cone angle is within `0...180`;
- cone feather is within `0...1`;
- all numeric values are finite.

Null, guide, camera, and light layers must use `normal` blend mode and an empty operation list in schema 2. Adjustment layers must also use `normal`; their opacity is the adjustment mix. Media and nested-composition layers may use all four implemented blend modes.

### 3.6 Static transform

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

Defaults:

```text
position = (0.5, 0.5)
anchor = (0.5, 0.5)
scale = (1, 1)
rotation = 0
opacity = 1
```

Position and anchor use composition-normalized top-left coordinates. All values are finite, both scales are positive, opacity is `0...1`, and rotation preserves the finite user value without forced wrapping.

### 3.7 Operations and blend modes

Persisted operations are independent of Metal:

```text
LayerOperation
├── exposure(stops)
├── saturation(value)
└── invert(enabled)
```

Exposure and saturation values must be finite; saturation is nonnegative. Media/nested operations run before blending. Adjustment operations run on the accumulated result below and are mixed with the original accumulator by layer opacity.

Schema 2 blend modes are exactly:

```text
normal
add
multiply
screen
```

Overlay, Soft Light, Difference, Darken, Lighten, Color Dodge, and Color Burn require a later schema and shader extension and are neither selectable nor writable in Phase 6.

### 3.8 Enabled, Solo, and missing media

The compiler filters by enabled state and time range first.

- when no active layer is solo, every active render-capable layer participates;
- when any active layer is solo, only active solo layers participate;
- adjustments follow the same Solo filter;
- a solo adjustment with no participating pixels below operates on transparency;
- model-only layers produce no pixels;
- missing media is an error only when its media layer survives enabled, timing, and Solo filtering.

## 4. Schema 1 to schema 2 migration

### 4.1 Recovery before migration

A schema 1 package first goes through the existing schema 1 load/recovery process. Valid pending schema 1 journal records are replayed with the schema 1 command engine to produce one recovered logical document snapshot. Migration runs on that snapshot only; it does not combine unrelated autosave or backup candidates.

Because schema 1 command payloads are not schema 2 command payloads, the new schema 2 package starts with:

```text
empty Undo/Redo history
committed journal sequence = 0
empty journal
revision retained from recovered schema 1 snapshot
```

Migration itself is not an Undo command.

### 4.2 Non-destructive package behavior

The schema 1 package is not overwritten. The app creates a new internal working package, writes schema 2 canonical data, validates checksum and readback, then opens the new package. Failure leaves the source package untouched.

The existing app-specific `.aeproject` extension and UTI remain unchanged in Phase 6. This does not claim Adobe `.aep` compatibility.

### 4.3 Deterministic conversion

For each schema 1 composition placeholder:

- reuse its ID;
- retain its non-empty name;
- assign old output width and height;
- assign project frame rate and color;
- assign a ten-second exact duration;
- use a transparent background;
- start with empty Z-order.

When no placeholder exists, derive one default composition ID from the project ID and a fixed domain string and create `Main Composition`.

Retain a valid active composition. Otherwise choose the first composition in canonical ID order.

When `selectedMediaID` is valid:

- deterministically derive a media-layer ID from project ID, active composition ID, and media ID;
- create one media layer in the active composition;
- use zero source start and the full composition In/Out range;
- migrate old transform, opacity, exposure, saturation, and inversion;
- use `normal` blend mode;
- preserve selected media and select the new layer.

When no selected media exists, create no fake layer and preserve old values in `legacyRenderSettings`.

Derived IDs use SHA-256 over an explicit UTF-8 domain and stable IDs. The first 16 digest bytes are mapped to an RFC 4122 UUID with version bits `0101` and variant bits `10`. Identical source bytes produce identical IDs and canonical schema 2 bytes.

### 4.4 Failure conditions

Migration fails without authoritatively publishing a new package when source JSON is malformed, schema 1 recovery fails, generated ownership is invalid, references are missing, canonical validation fails, or readback/checksum validation fails.

## 5. Commands and history

### 5.1 Composition commands

```text
createComposition(composition, ownedLayers, insertionContext)
removeComposition(composition, ownedLayers, previousActiveID, previousSelection)
renameComposition(compositionID, before, after)
setActiveComposition(before, after)
setCompositionDimensions(compositionID, before, after)
setCompositionDuration(compositionID, before, after)
setCompositionFrameRate(compositionID, before, after)
setCompositionBackground(compositionID, before, after)
duplicateComposition(sourceID, duplicateComposition, duplicateLayers)
```

A nested-referenced composition cannot be removed. Removing an unreferenced composition removes its owned layers as one reversible command payload. Duplication derives new stable identities before the command is recorded and remaps internal nested references only when they point within the duplicated payload.

### 5.2 Layer commands

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

Every record carries project identity, base revision, command ID, timestamp, exact before/after data, inverse operation, and optional merge key.

Preconditions are exact. Insert requires absent identity and valid index. Remove requires matching full record and index. Reorder requires matching current index. Property edits require current value equal to `before`. Nested source edits validate the complete dependency graph.

Transform sliders merge by project, layer, property, and active gesture. Paired X/Y position may use one transaction key. Blend-mode changes are separate Undo entries. Undo of deletion restores the same identity, record, and exact index.

Durability order:

```text
validate
→ append and synchronize journal
→ apply command
→ increment revision
→ update history
→ schedule autosave
```

Journal preparation failure leaves project, Z-order, selection, history, and preview source state unchanged.

## 6. VertexComposition compiler

### 6.1 Public contracts

```text
CompositionRenderRequest
├── project
├── compositionID
├── exact time
├── output descriptor
├── project revision/cache context
└── limits

CompositionFrameResolution
├── frame(PortableImage)
└── transparent

CompositionFrameResolver
└── resolve(mediaID, exactSourceTime, targetSize) async throws

CompositionGraphCompiler
└── compile(request, resolver, cancellationToken) async throws -> RenderRequest
```

No URL, AVFoundation, Metal, UIKit, or SwiftUI type appears in these contracts.

### 6.2 Z-order and adjustment expansion

The compiler begins with a deterministic background source and traverses `layerIDs` from bottom to top.

Media or nested layer:

```text
source/subcomposition
→ node-local operations and transform
→ composite over current accumulator
```

Adjustment layer:

```text
current accumulator
→ adjustment operations
→ mix by adjustment opacity
→ continue with layers above
```

Adjustments never affect layers above them.

### 6.3 Nested compositions

Nested compositions compile recursively into the same graph. The child root becomes a parent layer input. A composition-ID stack rejects direct and indirect cycles.

Limits:

- composition size: `8192 × 8192`;
- stored layers per composition: `256`;
- nested depth: `16`;
- expanded graph nodes: `4096`.

Limit failure produces no partial successful result.

### 6.4 Request-local frame cache and cancellation

The resolver cache key is:

```text
mediaID + exact source time + requested target dimensions
```

Identical requests resolve once per render. The cache is discarded afterward.

Cancellation is checked before and after every frame resolution, before nested descent, after each compiled layer, and before backend submission. A stale request cannot publish over a newer preview.

## 7. VertexRender graph changes

### 7.1 Node kinds

```text
RenderNodeKind
├── source(PortableImage)
├── operations([RenderOperation])
├── composite(RenderBlendMode)
├── adjustment([RenderOperation], mix)
└── output
```

`RenderOperation` gains an exact node-local 2D transform form containing anchor, position, independent scale, and rotation. Existing exposure, saturation, invert, and opacity operations remain explicit.

### 7.2 Validation and execution semantics

- exactly one output is required;
- multiple sources are allowed;
- source has zero dependencies;
- operations and adjustment have one dependency;
- composite has two ordered dependencies: `[backdrop, source]`;
- output has one dependency;
- duplicate IDs, missing dependencies, disconnected nodes, and cycles fail;
- composite dependency order is semantic and is never sorted away;
- every operation and blend mode validates before GPU work.

The backend no longer obtains one global source through `sourceImage()` or flattens all operations through `flattenedOperations()`. It evaluates nodes in validated topological order and applies operations only to the node that owns them.

The cache context includes composition ID, exact time, project revision, graph bytes, and output descriptor.

## 8. Metal compositing

### 8.1 Pipelines

```text
vertexLayerKernel
vertexCompositeKernel
vertexAdjustmentKernel
```

The layer kernel applies anchor-aware transform, normalized position, independent scale, rotation, exposure, saturation, inversion, opacity, and premultiplication.

The adjustment kernel applies operations to the accumulator and mixes original and adjusted results by adjustment opacity.

### 8.2 Premultiplied alpha and blend formulas

Internal composition textures use premultiplied alpha. Straight decoded input is converted before blending. Fully transparent RGB cannot affect output.

For straight source color `Cs`, backdrop color `Cb`, source alpha `as`, backdrop alpha `ab`, and blend function `B`:

```text
ao = as + ab × (1 - as)
Co-premul =
    as × (1 - ab) × Cs
  + as × ab × B(Cb, Cs)
  + ab × (1 - as) × Cb
```

```text
normal:   B(Cb, Cs) = Cs
add:      B(Cb, Cs) = clamp(Cb + Cs)
multiply: B(Cb, Cs) = Cb × Cs
screen:   B(Cb, Cs) = 1 - (1 - Cb) × (1 - Cs)
```

Phase 6 uses deterministic Rec.709 SDR fixtures and preserves color metadata. Full gamut, transfer-function, HDR, ACES, and OCIO management remains Phase 22.

### 8.3 Texture lifetime and metrics

A linear composition chain uses two full-size accumulator textures in ping-pong order plus transient source/layer textures. Nested outputs and intermediates are released after last use and compatible textures are reused.

Metrics include decoded input pixels, output pixels, expanded nodes, rendered layers, estimated peak texture bytes, CPU encoding time, GPU time when available, and total time.

GPU allocation, pipeline, command-buffer, or readback failure returns a structured error and no partial successful frame.

## 9. Application workspace

```text
CompositionWorkspaceView
├── CompositionHeader
├── CompositionPreview
├── ExactFrameNavigator
├── LayerList
├── LayerInspector
└── ProjectPersistenceControls
```

The existing Open, Save, package Export, Undo, Redo, autosave, relink, embed, and recovery controls remain.

Composition header supports select, create, duplicate, rename, dimensions, frame rate, duration, and remove. Referenced deletion reports an explicit error.

The exact-frame navigator supports first, previous, next, last, direct frame entry, and simple scrub. UI Double values are immediately converted to an exact frame index and are never persisted as source-of-truth time. This is not the Phase 9 NLE timeline.

The layer list displays top Z-order first and exposes type, name, enabled, locked, solo, current-time activity, blend mode, missing status, and model-only status. A drag is one reorder command.

Add options are Media, Adjustment, Null, Guide, Camera, Light, and Nested Composition.

The inspector exposes supported properties only. A locked layer can only be unlocked through its explicit lock control. Camera/light fields are labeled as having no Phase 6 output effect.

Media resolution order is:

```text
verified embedded file
→ valid external security-scoped bookmark
→ missing-media error and relink flow
```

The app adapter resolves exact AVFoundation frames and returns `CompositionFrameResolution`.

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

Persistent validation and compilation both verify ownership and cycles. Future schemas are not decoded as writable projects. Deleting a layer does not delete its media record. Unsupported model-only data never silently changes pixels. The app keeps the last successful preview when a newer request fails and displays the current error.

## 11. Tests

### 11.1 Schema and migration

- deterministic schema 1→2 bytes and derived IDs;
- placeholder reuse and no-placeholder default composition;
- selected-media Render Lab migration;
- legacy values preserved without selected media;
- schema 1 journal replay before migration;
- new schema 2 history and journal reset;
- source package unchanged on success and failure;
- registry canonicalization with Z-order preservation;
- duplicate IDs, ownership mismatch, missing references, invalid timing, invalid transform, and direct/indirect cycles rejected.

### 11.2 Commands and persistence

- composition create, duplicate, delete, rename, dimensions, duration, frame rate, background, and active selection;
- referenced-composition deletion rejection;
- layer insert, remove, duplicate, rename, select, and exact reorder;
- full identity/record/index restoration on Undo;
- transform merge and independent blend Undo;
- enabled, locked, solo, timing, source, operation, camera, and light commands;
- journal-before-mutation and failure atomicity;
- save/reopen, autosave, recovery, relink, and embed with schema 2 ownership and order.

### 11.3 Compiler

- exact bottom-to-top expansion;
- enabled, timing, and Solo filtering;
- participating-only missing-media failure;
- adjustment affects only below;
- nested source offset, parent In/Out, negative time, and child-duration behavior;
- frame deduplication;
- cycle and resource limits;
- cancellation;
- deterministic graph and cache context.

### 11.4 Metal fixtures

- Normal Source Over;
- Add, Multiply, and Screen;
- semitransparent edges;
- transparent-RGB contamination prevention;
- position, anchor, independent scale, rotation, opacity;
- exposure, saturation, inversion;
- adjustment operations and mix;
- two or more real sources;
- nested composition;
- preview/PNG byte equality.

### 11.5 Regression gates

All previous exact-time, identity, color metadata, media, waveform, render, Metal, deterministic codec, command, journal, atomic save, autosave, recovery, relink, embed, and product-policy tests remain green.

## 12. Completion gate

Phase 6 is complete only when:

- schema 2 and non-destructive deterministic migration pass;
- real multi-media-layer rendering passes;
- four blend modes pass Metal pixel fixtures;
- adjustment and nested compositions render correctly;
- null, guide, camera, and light persist and support commands without false output claims;
- Linux portable tests pass;
- native macOS project tests pass;
- native Metal tests and shader compilation pass;
- iOS 17 arm64 Release build passes;
- identity, version `6.0.0 (6)`, assets, architecture, and Metal resources are inspected;
- `After-Effects-6.0.0-unsigned.ipa` is downloaded and its SHA-256 recorded;
- completion, test, work-log, versioning, README, and handoff documents are updated;
- Draft PR #6 remains stacked on Phase 5 and is not merged automatically.

## 13. Engineering rules

- TDD is mandatory for schema, commands, compiler, and blend behavior.
- Decorative layer UI cannot precede real command and render semantics.
- Preview and output cannot diverge.
- Exact `RationalTime`, deterministic persistence, non-destructive recovery, source-license traceability, and honest status cannot weaken.
- Project data cannot persist AVFoundation, Metal, UIKit, SwiftUI, security-scoped URL objects, file descriptors, or absolute sandbox paths.
- No new external source code is required. Existing audited third-party candidates remain unlinked unless separately reviewed and approved.
