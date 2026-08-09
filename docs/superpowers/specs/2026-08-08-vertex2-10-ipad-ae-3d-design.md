# Vertex2 10.0.0 iPad AE Workspace and 3D Design

Date: 2026-08-08
Status: design approved in conversation, written-spec review pending
Target branch after review: `agent/phase10-ipad-ae-3d`
Baseline: `agent/phase9-release-staging`

## 1. Release intent

Vertex2 10.0.0 is a deliberate roadmap insertion. It replaces the previously planned 10.0.0 Time Engine release with an iPad-only professional workspace and real 3D editing release. Every existing roadmap item from the old 10.0.0 onward moves forward by one public major version. The old 10.0.0 becomes 11.0.0, the old 11.0.0 becomes 12.0.0, and so on through the previous final 27.0.0 qualification release, which becomes 28.0.0.

The 10.0.0 release is not a cosmetic reskin. Completion requires working editing behavior, schema migration, deterministic tests, iPad Simulator coverage, real iOS arm64 Release compilation, functional export, inspected IPA contents, and a verified SHA-256 checksum.

Release identity:

- Product name: `Vertex2`
- Marketing version: `10.0.0`
- Build: `10`
- Bundle identifier: `com.woo642778.aftereffects`
- Minimum OS: iPadOS 17.0
- Device family: iPad only
- Supported interface orientation: landscape left and landscape right only
- Final artifact: `Vertex2-10.0.0-unsigned.ipa`

## 2. Product direction

The UI becomes an iPad-native interpretation of an After Effects desktop workspace rather than an enlarged phone UI. The application keeps the layer-based editing model while exposing project media, composition preview, effect/property inspection, timeline editing, 3D manipulation, and export through one coherent workspace system.

The interface must remain usable across supported iPad sizes, including smaller landscape iPads, 11-inch and 13-inch iPad Pro class screens, Stage Manager windows, Split View sizes that remain supported by the OS, and external displays. No important panel may rely on a single fixed pixel width.

The implementation must preserve the existing project/render architecture where possible. New UI may reorganize access to existing functionality, but must not fork a second project model, timeline model, animation engine, or export render semantic path.

## 3. iPad-only platform conversion

`project.yml` will target device family `2` only. iPhone orientation keys and the iPhone-specific editor entry path will no longer participate in the application target. The app supports only landscape left/right on iPad.

The code may retain isolated reusable compact controls where useful, but the shipping product no longer maintains a separate iPhone editor experience. CI replaces iPhone app-test coverage with an iPad matrix.

The target must remain responsive when iPadOS presents a narrower Stage Manager window. Landscape-only does not justify fixed screen dimensions.

## 4. Adaptive workspace system

The current simple `HStack`/`VStack` arrangement is replaced by a workspace layout model that owns panel identity, preferred size, minimum size, maximum size, collapsed state, tab grouping, and user-resized split positions.

The default Standard workspace contains:

- top application toolbar;
- upper-left Project panel;
- lower-left Effects & Presets panel;
- center Composition panel;
- right Effect Controls / Properties inspector stack;
- lower full-width Timeline panel;
- Graph Editor as a Timeline mode rather than a permanently competing panel;
- panel tabs, close/collapse controls, and draggable split handles.

Workspace presets:

- Standard: closest to the supplied AE-style concept image;
- Minimal: Composition + Timeline with side panels collapsed;
- Effects: larger Effect Controls and Effects & Presets panels;
- 3D: scene/asset hierarchy, Composition/3D viewport, Properties/Material inspector, Timeline;
- Export: render settings, output preview, job status/history and diagnostics.

User split positions are persisted as normalized proportions with hard minimum/maximum constraints instead of absolute screen pixels. A workspace can be restored safely on a different iPad size.

### Width adaptation

The layout uses behavioral width bands rather than device-name checks.

Wide band, approximately 1180 pt and wider:

- left dock visible as two stacked panels;
- right inspector visible;
- Composition receives the largest flexible center region;
- Timeline uses the full lower region;
- all splitters are directly draggable.

Medium band, approximately 980-1179 pt:

- Project and Effects & Presets may share a tabbed left dock;
- right inspector remains visible but uses a smaller preferred width;
- Timeline remains permanently visible;
- Composition remains the dominant upper panel.

Narrow Stage Manager band, below approximately 980 pt where the OS permits it:

- Composition and Timeline remain primary;
- left dock collapses into a tab/overlay drawer;
- right inspector becomes a toggleable overlay or tabbed drawer;
- no text is permitted to compress into one-character vertical columns;
- controls use horizontal scrolling or explicit grouping instead of accidental clipping.

These thresholds are implementation starting points, not hard-coded device assumptions. Tests verify behavior near every boundary.

### Height adaptation

Timeline height is user-resizable and stored as a normalized split. The initial Standard value is about 30-34% of available workspace height, clamped so both Composition and Timeline remain usable. Small windows may increase Timeline proportion but must not hide the Composition viewer entirely.

## 5. AE-style visual language

The supplied concept image is the visual target for spatial organization, not a requirement to copy Adobe branding or proprietary icons.

The app adopts:

- neutral near-black and dark-gray panel surfaces;
- restrained accent color used for selection, keyframes and active tools;
- thin panel dividers;
- compact desktop-style tab headers;
- dense but readable control rows;
- small icon toolbar with text tooltips/accessibility labels;
- visible panel titles such as Project, Effects & Presets, Composition, Effect Controls and Timeline;
- Composition viewer surrounded by black rather than a bright application-colored background;
- timeline rows with AE-like switch columns, layer color labels, in/out bars and keyframe lanes;
- workspace preset selector in the top toolbar.

The visual hierarchy must prioritize user media and composition content over chrome.

## 6. Input model

Touch, Apple Pencil, pointer/trackpad, and keyboard are first-class inputs.

Default roles:

- one-finger touch: selection and direct controls;
- two-finger gestures: pan/zoom where context permits;
- Apple Pencil: precise mask, keyframe path, vertex/edge/face and gizmo manipulation;
- pointer/trackpad: hover states, resize cursors, context menus and precision dragging;
- keyboard: playback, frame stepping, tool switching, delete, duplicate, undo/redo and common timeline operations.

No core 3D operation may require Apple Pencil. Pencil improves precision but is not mandatory.

## 7. Architecture boundaries

10.0.0 adds 3D without turning the app target into a monolith.

Expected module boundaries are:

- `VertexScene3D`: portable scene graph, math, mesh topology, materials, cameras, lights, primitives, validation and deterministic mesh operations;
- `VertexSceneIO`: portable glTF/GLB decoding and normalized import contracts;
- `VertexSceneIOApple`: Apple-platform USDZ/Model I/O bridge and texture decoding where platform APIs are required;
- `VertexRender3D`: backend-neutral render descriptions that connect scene evaluation to the existing render graph;
- `VertexRenderMetal`: Metal execution for mesh/depth/material/light/shadow passes, extending rather than bypassing the existing GPU path;
- `VertexProject`: canonical schema, 3D assets/layers/material references and migration;
- app workspace views: layout, scene viewport, inspectors, selection and commands only, with no duplicated creative model hidden in SwiftUI state;
- export service: AVFoundation/file-output orchestration that consumes the same evaluated composition/render path used by preview.

Exact package target names may be adjusted during implementation only if the dependency boundaries remain equivalent and tests stay isolated.

## 8. 3D scope for 10.0.0

10.0.0 deliberately pulls forward the useful core of the previous later 3D roadmap. The release combines AE-style 2.5D compositing with imported 3D models and a constrained mesh-editing toolset.

### 8.1 2.5D and transform model

Layer transforms gain a 3D-capable representation with:

- Position X/Y/Z;
- Scale X/Y/Z;
- Orientation;
- Rotation X/Y/Z;
- 3D anchor point;
- 2D/3D layer switch;
- parent-child world transform evaluation in 3D;
- stable conversion/migration from existing 2D transforms;
- animation channels for all animatable 3D transform properties.

The project schema is incremented for these additions. Existing 9.x projects must migrate without changing their rendered 2D result.

### 8.2 3D asset registry

The project gains a 3D asset representation separate from ordinary video/image media where necessary. A 3D asset records stable identity, source/provenance information, imported mesh structure, materials, texture references and validation metadata.

Supported import targets for 10.0.0:

- GLB;
- glTF 2.0;
- USDZ.

The importer must reject malformed or unsupported constructs with explicit diagnostics rather than silently producing broken geometry.

The glTF/GLB path implements a tested documented subset sufficient for static meshes, node transforms, PBR metallic-roughness materials and referenced textures. USDZ may use platform-supported Model I/O infrastructure where appropriate, but render data is normalized into Vertex-owned scene structures.

### 8.3 Scene and layer integration

3D objects exist in the same composition/timeline system as 2D layers. Camera and light sources already present in the project model become active rendered participants instead of model-only placeholders.

The scene supports:

- mesh object layers;
- camera layers;
- point, directional and spot lights;
- 2D media layers placed as 2.5D cards;
- mixed 2D/3D depth compositing;
- object hierarchy/parenting;
- visibility, lock and solo state;
- keyframed object, camera and light properties.

## 9. 3D workspace UI

The 3D workspace keeps the same overall AE panel grammar so users do not enter a separate application.

Left side:

- Project / 3D Assets tabs;
- Scene hierarchy with object, camera and light icons;
- create/import actions.

Center:

- Composition/3D viewport;
- perspective and orthographic editing views;
- camera view;
- orbit, pan and dolly navigation;
- grid, axis and safe-frame overlays;
- transform gizmos;
- vertex/edge/face selection overlays in Mesh Edit mode.

Right side inspector:

- Transform;
- Geometry;
- Material;
- Camera;
- Light;
- Object properties.

Bottom:

- same timeline used by 2D editing;
- object/camera/light layers animate with existing keyframe infrastructure;
- Graph Editor remains available for their animation channels.

3D workspace state such as view camera, shading mode and selection is session/UI state and must not accidentally modify render output unless explicitly represented in project data.

## 10. Mesh editing scope

10.0.0 supports basic editing useful for motion graphics, not Blender-class full modeling.

Required editing operations:

- object-level translate/rotate/scale;
- vertex selection and movement;
- edge selection;
- face selection;
- delete selected mesh elements where topology remains valid;
- face extrusion;
- inset;
- bevel with bounded segment count;
- basic subdivide;
- merge compatible selected vertices;
- primitive creation: plane, cube and sphere;
- 3D text creation with deterministic text-to-mesh geometry suitable for extrusion and scene rendering.

The underlying editable topology uses stable element identity suitable for Undo/Redo and deterministic tests. A half-edge or equivalent adjacency-aware representation is preferred over ad-hoc triangle mutation.

Out of scope for 10.0.0:

- sculpting;
- UV unwrap authoring;
- character rigging;
- skinning editor;
- physics simulation;
- particle simulation;
- advanced procedural modifiers;
- Blender-style node materials.

## 11. Materials and rendering

The first real 3D renderer remains Metal-based and integrates with the existing Vertex render architecture instead of creating an unrelated renderer.

Minimum material model:

- base color;
- base color texture;
- metallic;
- roughness;
- metallic-roughness texture where imported;
- normal texture;
- opacity/alpha mode subset;
- double-sided flag where supported.

Minimum lighting/render behavior:

- depth buffer;
- perspective camera;
- orthographic editor view;
- point/directional/spot light evaluation;
- basic shadows with a bounded mobile-friendly implementation;
- environment/background representation;
- camera near/far clip;
- camera depth of field with explicit performance quality settings;
- correct ordering between opaque 3D surfaces, 2.5D layers and supported transparent content;
- deterministic preview/export semantics.

The renderer prefers predictable mobile behavior over physically exhaustive features. Unsupported imported material extensions must be reported.

## 12. Export workspace

10.0.0 includes a functional Export workspace. It is not only a mock settings page.

The Export workspace provides:

- active composition selection;
- output filename/location;
- resolution presets and custom dimensions constrained by supported limits;
- frame rate sourced from the composition with explicit override only where valid;
- H.264 and HEVC output where AVFoundation/platform support is available;
- quality/bitrate control at an appropriate abstraction level;
- audio include/exclude option where project audio exists;
- alpha export only when a supported codec/path actually preserves alpha;
- estimated/output diagnostics where available;
- progress;
- cancellation;
- clear failure reporting;
- completed output handoff through iPadOS share/file workflows.

The initial release may support one active render job at a time. The later roadmap item for scale/cache/final export remains responsible for persistent multi-job render queues, checkpoint/resume, proxy/cache architecture and long-project production hardening.

Export must use the same composition evaluation and 3D renderer semantics as preview. A separate simplified export renderer is forbidden.

## 13. Workspace state and persistence

Workspace layout preferences are UI preferences, not canonical creative project state. Panel proportions, collapsed tabs and selected workspace preset are persisted separately from `.vertexproject` contents so opening a project on another iPad does not mutate document revision.

Creative 3D scene data, object transforms, materials, meshes, camera/light settings and animation are canonical project data and participate in deterministic save/migration/recovery.

## 14. Undo/Redo and commands

Every creative editing operation introduced in 10.0.0 flows through deterministic project commands compatible with session Undo/Redo.

This includes:

- toggling 2D/3D layer mode;
- changing 3D transforms;
- importing/removing 3D objects;
- material edits;
- camera/light edits;
- mesh vertex moves;
- extrude/inset/bevel/subdivide/merge/delete operations;
- primitive creation;
- 3D text creation and geometry edits.

Pure viewport navigation, workspace resize and panel tab state are not creative Undo operations.

## 15. Error handling

Failures are surfaced at the workspace that caused them and must not corrupt project state.

Examples:

- invalid glTF/GLB/USDZ: import fails transactionally and reports the unsupported construct;
- mesh operation creating invalid topology: command rejected before canonical state mutation;
- missing texture: object remains loadable with an explicit missing-resource state;
- GPU allocation/render failure: viewer reports degraded/failure state without modifying project data;
- export failure: partial output is cleaned up or clearly marked incomplete;
- migration failure: original package remains recoverable and no destructive save occurs.

## 16. Roadmap renumbering

The public roadmap becomes a 29-phase program, phases 0 through 28.

The new sequence from 10 onward is:

| Version | Program |
|---:|---|
| 10.0.0 | iPad AE Workspace, 2.5D/3D, Basic Mesh Editing, Functional Export Workspace |
| 11.0.0 | Time Engine and Retiming |
| 12.0.0 | Professional Color, HDR, and Scopes |
| 13.0.0 | Audio Studio |
| 14.0.0 | Text and Vector Engine |
| 15.0.0 | Tracking, Stabilization, and Rotoscoping |
| 16.0.0 | Effects Architecture |
| 17.0.0 | Advanced Pre-composition and Nesting |
| 18.0.0 | Particles and Procedural Graphics |
| 19.0.0 | Node Compositor |
| 20.0.0 | AI Studio |
| 21.0.0 | AI Upscale and Restoration |
| 22.0.0 | Asset and Preset Ecosystem |
| 23.0.0 | Advanced 3D Foundation Hardening |
| 24.0.0 | Advanced 3D Scene Workspace |
| 25.0.0 | Advanced Camera, Light, and 3D Rendering |
| 26.0.0 | Expressions, Automation, and Extensibility |
| 27.0.0 | Scale, Cache, and Final Export Architecture |
| 28.0.0 | Interchange and Release Qualification |

Versions 23-25 retain the intent of the old 3D phases but become advanced/hardening releases because the usable core is deliberately pulled forward into 10.0.0. They may add larger-scene performance, more import/material coverage, advanced geometry/modifiers, rendering quality, render passes and other capabilities without duplicating the 10.0.0 acceptance criteria.

Canonical roadmap documents and README version tables must be updated consistently during implementation. Any file name that encodes the obsolete phase count is migrated or replaced with a compatibility redirect note so future contributors do not see contradictory numbering.

## 17. Test strategy

### Portable/model tests

- schema migration from current schema 5 to the new 3D-capable schema;
- unchanged rendering semantics for migrated 2D projects;
- 3D transform composition and parenting;
- camera matrix math;
- light parameter validation;
- stable mesh element identities;
- deterministic mesh edit operations;
- invalid topology rejection;
- glTF/GLB fixture parsing;
- USDZ import normalization fixture where supported;
- material validation;
- deterministic 3D text geometry;
- project command Undo/Redo for 3D edits.

### Render tests

- depth ordering;
- perspective projection;
- 2.5D card + mesh compositing;
- point/directional/spot lighting;
- shadow fixture;
- transparent/opaque ordering for the supported subset;
- camera DOF fixture at bounded quality;
- 3D text rendering;
- preview/export parity.

### UI/app tests

Run iPad Simulator tests at representative geometries, at minimum:

- an 11-inch-class iPad landscape target;
- a 13-inch-class iPad landscape target;
- a narrower resizable-window geometry where automation permits.

Tests verify:

- no clipped panel titles;
- no character-by-character accidental text compression;
- splitter resizing and bounds;
- panel collapse/restore;
- Standard/Minimal/Effects/3D/Export workspace switching;
- timeline remains accessible across size bands;
- 3D selection and inspector linkage;
- export settings validation.

There is no iPhone app-test gate for 10.0.0 because the product is iPad-only.

### Release tests

- full Swift test suite;
- iPad app/session tests;
- Metal shader compile tests;
- real Core ML regression tests already required by the product where applicable;
- iOS 17+ `iphoneos` arm64 Release build for the iPad-only target;
- app bundle inspection;
- version/build/bundle ID/device-family/orientation verification;
- required AI resource checks inherited from 9.0;
- unsigned-state verification;
- IPA creation and independent audit;
- SHA-256 generation and re-verification.

## 18. Implementation decomposition

10.0.0 is implemented as isolated milestones so the branch never relies on a giant visual-only rewrite.

1. Roadmap/version insertion and iPad-only target contract.
2. Adaptive workspace layout model and panel persistence.
3. AE-style Standard/Minimal/Effects workspace UI using existing editing behavior.
4. Project schema migration for 3D transforms/assets/scenes.
5. `VertexScene3D` math, hierarchy, topology, camera/light and material foundations.
6. Metal depth/mesh/material renderer integrated with composition preview/export.
7. GLB/glTF/USDZ import normalization.
8. 3D workspace, viewport navigation and gizmos.
9. Mesh topology, primitive creation and deterministic 3D text geometry.
10. Vertex/edge/face editing plus extrude/inset/bevel/subdivide/merge/delete.
11. Material/camera/light inspectors and animation-channel integration.
12. Functional Export workspace and single-job output path.
13. Adaptive iPad UI test matrix and 3D/render regression hardening.
14. 10.0.0 release gate, IPA audit and SHA-256 evidence.

Each milestone leaves compilation/tests green for the code it touches. UI controls are not considered implemented until their backing command/render/export behavior exists.

## 19. Acceptance criteria

Vertex2 10.0.0 is complete only when all of the following are true:

- the shipping target is iPad-only and landscape-only;
- the workspace adapts across supported iPad window sizes without the clipping shown in the 9.0 phone test;
- the Standard workspace materially matches the supplied AE-style layout concept in information architecture;
- panel splitters and workspace presets function;
- existing project/timeline/effect behavior remains operational;
- 2D projects migrate without visual semantic change;
- GLB, glTF and USDZ validated fixtures import into canonical editable 3D scene data;
- 3D object import produces editable/rendered scene objects;
- cameras and lights affect the actual rendered result;
- 2.5D layers and 3D meshes coexist in one composition;
- required basic mesh editing operations mutate real topology and participate in Undo/Redo;
- 3D text produces real renderable geometry;
- 3D transforms and relevant properties can be keyframed through the existing animation architecture;
- Export produces a real playable output file for at least one validated delivery codec;
- preview and export share render semantics;
- all required portable, iPad, Metal and release tests pass;
- the final unsigned IPA reports `Vertex2`, `10.0.0`, build `10`, bundle ID `com.woo642778.aftereffects`, iPad-only device support and iPadOS 17 minimum deployment;
- SHA-256 is generated and independently verified.
