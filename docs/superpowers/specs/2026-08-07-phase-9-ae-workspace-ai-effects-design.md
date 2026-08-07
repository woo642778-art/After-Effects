# Vertex2 9.0 — AE-Style Workspace, Professional Timeline, and Layer-Integrated AI Effects

Date: 2026-08-07
Status: Approved design specification
Target release: Vertex2 9.0.0 (build 9)
Target artifact: `Vertex2-9.0.0-unsigned.ipa`
Base: `agent/phase-8-vertex2-motion-masks`
Implementation branch: `agent/phase-9-ae-workspace-ai-effects`

## 1. Goal

Vertex2 9.0 turns the current vertically stacked composition tools into a professional layer-compositing workspace whose editing flow is intentionally close to Adobe After Effects while remaining a native Swift/SwiftUI/Metal application with Vertex2-owned data models and render code.

The release must not be a visual skin. The workspace, timeline, effect controls, project commands, renderer, AI inference, cache, persistence, undo/redo, preview, and export semantics must be connected end to end.

The defining user-visible behavior is:

1. A layer is selected in an AE-style timeline.
2. `Depth Map`, `Cutout`, `Upscale`, or `Restore` can be added to that layer as a non-destructive effect.
3. The effect immediately participates in the selected layer's render graph.
4. Current-frame inference is scheduled at high priority and already-cached frames are reused immediately.
5. The Composition Viewer is refreshed as soon as an AI result becomes available.
6. Disabling or deleting the effect removes it from the render graph and immediately exposes the original layer again without altering source media.
7. `Extract / Bake to Layer` computes and validates a durable derived result, registers it as project media, and atomically inserts a new layer in the timeline above the source layer.
8. All edits remain undoable, persist through save/reopen, and use the same preview/export semantics.

## 2. Product and platform target

### 2.1 Primary device

The primary editing surface is iPad in landscape orientation.

The iPad workspace uses four principal areas:

- Project panel on the left.
- Composition Viewer in the center.
- Effect Controls / Properties on the right.
- Layer Timeline across the bottom.

The exact panel widths are adaptive, but the panel roles and editing flow remain stable.

### 2.2 iPhone adaptation

iPhone uses the same project schema, timeline engine, render engine, commands, AI effect model, cache, and selection state. It does not receive a separate simplified document format.

The compact UI uses:

- Composition Viewer as the primary surface.
- Timeline as a persistent lower region or resizable bottom sheet.
- Project, Effect Controls, and Properties as tabbed/drawer panels.
- The same effect stack and timeline operations, with touch-appropriate controls.

An iPad project must open on iPhone without migration or feature loss.

## 3. Architectural constraints

Vertex2 remains native and keeps the existing render path:

`ProjectLayer -> CompositionGraphCompiler -> RenderGraph -> MetalGraphExecutor`

9.0 adds bounded subsystems rather than replacing that path:

- `TimelineEngine`: exact-time layer editing and timeline commands.
- `ProjectEffectStack`: persistent, ordered, non-destructive layer effects.
- `EffectEvaluator`: translates enabled effects at exact time into render/inference work.
- `AIFrameEffectService`: schedules Core ML/Vision work and exposes cacheable frame results.
- `AIEffectCache`: memory/disk cache keyed by exact effect inputs.
- `EditorWorkspaceState`: shared panel, selection, playhead, tool, and timeline-view state that is not itself the canonical project document.

UI code must not perform media decoding, AI inference, or pixel rendering directly.

Project mutations must pass through project commands so validation, undo/redo, autosave, and persistence invariants remain centralized.

## 4. Reference-source policy

The implementation may study public projects for architecture and interaction patterns, but Vertex2 must not copy incompatible implementation code.

Relevant references include:

- Natron for compositor/effect-graph interaction patterns. Treat GPL code as design reference only unless a separately compatible component is proven suitable.
- Olive for professional timeline/NLE interaction patterns. Treat GPL code as design reference only.
- OpenTimelineIO for rational-time editorial modeling, invariants, and test ideas. Vertex2 keeps its own canonical project format and exact-time types.
- Official Depth Anything V2 / related official depth repositories for model behavior and model licensing. Only weights and code with licensing compatible with Vertex2 distribution may be bundled.

Every newly bundled model or source component must have a recorded license and digest. License compatibility is a release gate, not a post-release task.

## 5. AE-style workspace

### 5.1 iPad layout

The main editor replaces the current card-like vertically stacked editing flow with a panel workspace.

Approximate structure:

```text
+----------------------+--------------------------------------+----------------------+
| Project              | Composition Viewer                   | Effect Controls      |
| media/comps/assets   | real GPU preview                     | layer/effects/masks  |
|                      |                                      | AI/status/params     |
+----------------------+--------------------------------------+----------------------+
| Layer Timeline                                                                    |
| switches | name | parent/matte | properties/effects | exact-time ruler        |
+-----------------------------------------------------------------------------------+
```

Panels share one selection/playhead state. Selecting a layer in Project/Timeline updates Effect Controls. Changing the playhead updates the Viewer and property/keyframe displays. Changing an effect parameter updates the project revision and causes the Viewer to re-evaluate.

### 5.2 Timeline row hierarchy

Each composition layer is a top-level timeline row. Disclosure reveals child property rows.

Minimum expandable groups:

- Transform
- Masks
- Effects

Transform exposes existing animated position, scale, rotation, opacity, anchor properties.

Masks expose each mask and its animatable path/opacity/feather/expansion properties.

Effects expose each effect and its animatable parameters.

The timeline must display property keyframes directly against the composition time ruler.

### 5.3 Layer switches and columns

The left timeline region must support the AE-style concepts needed by Vertex2, including:

- Visibility
- Solo
- Lock
- Guide
- Adjustment semantics where applicable
- Parent
- Track Matte
- Blend Mode

Shy and future 3D switches may be represented when their backing semantics exist, but a visible control must not pretend to work if the engine does not support it.

## 6. Professional timeline behavior

Phase 9 remains the professional NLE timeline milestone. AE-style layer editing is the default interaction model, while explicitly selected tools provide ripple/roll/slip/slide operations.

### 6.1 Exact-time source of truth

The playhead and edit boundaries use `RationalTime` or the repository's exact equivalent. UI pixels are projections of exact times; floating-point screen coordinates are never canonical edit values.

Edits committed at a frame boundary must remain stable after save/reopen and after repeated zoom changes.

### 6.2 Required layer timing state

A timed media/nested layer needs enough persistent state to distinguish:

- Layer placement in composition time.
- Layer in point.
- Layer out point.
- Source offset/source in point.
- Source duration bounds.

9.0 may add forward-compatible retime metadata, but advanced retiming itself remains a later phase.

### 6.3 Selection tool

The normal tool behaves like an AE layer timeline:

- Drag a layer in time.
- Trim in/out edges.
- Move keyframes.
- Multi-select layers/keyframes.
- Reorder layer stacking order.
- Do not ripple unrelated layers by default.

### 6.4 Split

Split at playhead creates two layers that reference the same source media while preserving source continuity. The source file is never destructively cut.

Effect, mask, animation, and matte state must be partitioned or copied according to deterministic rules so the rendered result immediately before and after the split is visually equivalent to the unsplit layer at the split boundary.

### 6.5 Ripple, roll, slip, and slide

These operations are explicit tools/actions, not implicit behavior of the normal selection tool.

- Ripple: changes an edit boundary and shifts affected following layer timing according to the selected scope.
- Roll: moves a boundary between adjacent eligible segments while preserving combined duration.
- Slip: preserves layer placement/in-out duration while moving source offset.
- Slide: moves a layer in composition time while adjusting adjacent eligible boundaries according to the selected scope.

Invalid operations must be rejected rather than silently clamped into a different edit.

### 6.6 Snapping

Snap targets include:

- Playhead
- Layer in/out points
- Composition start/end
- Work-area start/end
- Keyframes
- Markers

Snapping can be toggled globally from the timeline toolbar. Snap calculations use exact times with a screen-space threshold converted deterministically into timeline time.

### 6.7 Multi-selection

Support touch and keyboard workflows:

- Shift/touch modifier additive selection.
- Drag rectangle selection where appropriate.
- Command-modified selection with hardware keyboard.
- Group movement of compatible selected layers/keyframes as one undoable edit.

### 6.8 Timeline zoom and navigation

Support:

- Pinch zoom.
- Horizontal zoom control.
- Fit composition.
- Fit selected layers.
- Horizontal scrolling independent of layer-list vertical scrolling.

### 6.9 Work area and markers

Persist composition work-area start/end and composition/layer markers.

The work area initially governs preview range and may later be reused by render/export range selection.

Markers need stable identity, exact time, and a user-visible name/comment field. Composition markers and layer markers remain distinct.

### 6.10 Keyframes and Graph Editor

The timeline supports:

- Stopwatch animation enablement.
- Add/remove keyframe at playhead.
- Previous/next keyframe navigation.
- Keyframe drag.
- Box selection.
- Copy/paste.
- Hold/Linear/Cubic temporal interpolation where supported by the underlying animation channel.

A Timeline/Graph Editor mode switch exposes:

- Value Graph
- Speed Graph

The Graph Editor edits the existing animation channel semantics; it must not maintain a second competing animation model.

## 7. Parent and track-matte timeline integration

Parenting is exposed as a timeline column and pick-whip-style interaction. Parent changes must be project commands and must validate self-parenting/cycles.

Where the engine supports it, changing parent may offer preservation of current world-space appearance by recalculating local transform.

Track Matte controls are exposed directly on timeline rows and use the existing real Alpha / Alpha Inverted / Luma / Luma Inverted render behavior rather than a UI-only relationship.

## 8. Ordered non-destructive effect stack

### 8.1 Project model

`ProjectLayer` gains an ordered `effects` collection.

Each effect instance must have at least:

- Stable ID
- Effect type/version
- Enabled state
- Ordered parameters
- Parameter animation references/channels where applicable
- Persisted effect configuration

Transient cache/progress state must not be mixed into the canonical project effect definition.

### 8.2 Render semantics

The effect stack is ordered. Reordering effects changes render order deterministically.

For normal pixel-producing layers, the conceptual Phase 9 order is:

`Source -> Ordered Effects -> Masks -> Transform -> Track Matte -> Composite`

If an existing architecture requires a different order for a specific established effect class, that exception must be explicitly tested and documented. UI order and render order must never silently disagree.

### 8.3 Minimal Phase 9 effect architecture

The roadmap previously places the broad professional effects architecture in a later phase. Phase 9 therefore introduces only the minimum typed/versioned effect container and evaluator required for the approved 9.0 workflow, especially AI effects.

This does not claim completion of the later general-effects milestone. Later phases can extend the same container with larger GPU effect families, preset migration, and broader typed parameter systems.

## 9. Layer-integrated AI effects

9.0 moves AI from a detached utility workflow into the layer effect stack while reusing proven existing AI inference backends.

Required first-class AI effects:

- Depth Map
- Cutout
- Upscale
- Restore

### 9.1 Depth Map

Adding Depth Map to a layer must not replace the source media registry entry.

The selected layer's current rendered pixel source becomes the effect result whenever a valid result is available.

Minimum parameters:

- Model selection constrained to bundled/approved models
- Preview/final quality tier
- Invert
- Near/Far mapping
- Smoothing
- Edge refinement
- Temporal smoothing
- Output mode

Initial output modes should include at least a visible depth output. Additional depth-as-alpha/data modes may be added only when their render/export semantics are fully implemented.

Disabling/deleting the Depth Map effect removes it from evaluation and reveals the pre-effect layer immediately.

### 9.2 Cutout

Cutout is an alpha-producing layer effect.

Its normal effect-mode behavior changes the effective layer alpha rather than requiring the user to import a separate matte file.

Existing foreground/prompt controls may be surfaced through Effect Controls when supported by the current Vision/Core ML backend.

### 9.3 Upscale and Restore

Upscale/Restore use the same effect UX, but their interactive preview may use reduced resolution or a faster tier.

The effect definition remains identical between preview and final rendering. Preview quality may differ; effect meaning may not.

### 9.4 Effect state in UI

Effect Controls and the timeline effect row expose explicit state such as:

- Ready
- Computing
- Cached
- Stale
- Failed

A preview fallback to original pixels during an AI error or pending computation must be visibly labeled; the UI must not imply that AI output is being shown when it is not.

## 10. AI frame scheduler and cache

### 10.1 Cache key

A reusable AI frame result must be keyed by all semantics that can change the output, including:

- Source fingerprint
- Exact source/composition time required by the evaluator
- Model ID
- Model digest
- Effect type and algorithm version
- Canonical effect parameter digest
- Quality tier
- Target/inference resolution
- Orientation/color-space inputs required by the model pipeline

Changing any output-affecting input invalidates the corresponding cache identity.

### 10.2 Cache layers

Use bounded tiers:

- Small in-memory LRU for hottest decoded/inference results.
- Durable disk cache for verified reusable AI outputs/chunks.
- Project media assets only for explicit durable Extract/Bake results.

Runtime cache files are not canonical project media.

### 10.3 Scheduling priority

Priority order:

1. Current playhead frame.
2. Immediate frames in current playback direction.
3. Nearby work-area frames.
4. Background fill/prefetch.

Obsolete low-priority requests should be cancellable when the user scrubs elsewhere or changes output-affecting parameters.

Media decode and AI inference must remain off the main actor.

### 10.4 Definition of real-time

9.0 promises interactive invalidation and incremental response, not a false guarantee of full-resolution 30/60 fps neural inference on every supported device.

Expected behavior:

- Cached results appear immediately.
- Current-frame cache misses are scheduled immediately.
- Preview may use a lower quality/resolution tier.
- A stopped frame may refine to a higher preview quality.
- Export uses the requested final quality.

## 11. Extract / Bake to Layer

Every supported AI effect may expose an explicit `Extract / Bake to Layer` action when a durable media representation exists.

The workflow is transactional:

1. Resolve the source timing range.
2. Compute required output frames/chunks.
3. Finalize the media file.
4. Validate media readability, expected duration/frame count, model/recipe digest metadata, and project-package path safety.
5. Register derived media in the project.
6. Register the `ProjectAIAsset` relationship/recipe metadata.
7. Insert a new layer directly above the source layer with matching composition timing.
8. Commit all project-document mutations as one undoable project command/transaction.

Default naming:

- `<Source Layer> • Depth`
- `<Source Layer> • Cutout`
- `<Source Layer> • Upscale`
- `<Source Layer> • Restore`

If compute/finalization/validation fails or is cancelled before commit, no partial layer or half-registered media entry may remain in the project document.

Undo of the committed extraction must remove the inserted layer and project registrations consistently. Durable orphan cleanup can be deferred to package/cache maintenance only if the document itself is immediately correct.

By default the live source effect remains enabled after extraction unless the user explicitly chooses a replace/disable variant.

## 12. Preview and export parity

Preview and export use one effect semantic path through `EffectEvaluator` and the render graph.

Preview may lower resolution/quality, but it may not use an unrelated implementation.

For export:

- Missing AI frames are computed as required.
- Failed required AI inference must fail export with the effect ID/type, layer identity, and exact time in the error context.
- Export must not silently substitute the original source frame for a required AI result.

For interactive preview:

- A temporary source fallback is allowed for responsiveness.
- The UI must explicitly indicate computing/fallback/failed state.

## 13. Project commands, undo/redo, and gesture transactions

Timeline and effect UI never mutate `ProjectDocument` directly.

New command families should cover at least:

- Set layer timing
- Split layer
- Ripple edit
- Roll edit
- Slip edit
- Slide edit
- Reorder layer
- Set parent
- Set markers/work area
- Add/remove/reorder/update effect
- Set effect enabled state
- Set effect parameter/static value
- Set effect parameter animation
- Register extracted AI media + layer atomically

High-frequency gestures use mergeable/coalesced transactions. Dragging a trim handle through many touch updates should normally produce one logical undo step, not dozens.

Validation occurs before commit. A failed command must not leave a partially modified document.

## 14. Persistence and schema migration

Target project schema: 5.

Schema 4 -> 5 migration must preserve all existing:

- Compositions
- Media registry
- Layers
- Exact-time animation channels/keyframes
- Masks
- Track mattes
- Existing AI asset records

New Phase 9 state receives deterministic defaults:

- Empty effect stacks
- No parent unless already represented compatibly
- Empty markers
- Work area defaulting to composition range
- New timing metadata derived without changing the visible Phase 8 result

Migration output must be deterministic and validated by save/reopen regression tests.

App metadata target:

- Display name: Vertex2
- Marketing version: 9.0.0
- Build: 9
- Existing bundle identifier retained unless separately approved

## 15. Error handling

### 15.1 Timeline

Reject invalid exact-time edits with typed project/timeline errors. Do not silently turn one edit mode into another.

Examples:

- Source offset outside valid media range.
- Roll without valid adjacent editable segments.
- Parent cycle.
- Split outside visible layer range.
- Non-finite converted screen/time values.

### 15.2 Effects

Reject unknown/corrupt parameter encodings during validation/migration. Disabled effects remain serializable and reversible.

### 15.3 AI

AI failures expose useful state while preserving source safety.

Interactive preview may show original input with a visible failure indicator. Export and Bake must fail rather than claim success with missing required AI output.

Cancellation must be distinguishable from inference/model/file failures.

## 16. Testing strategy

9.0 is complete only with deterministic behavior and real build evidence.

### 16.1 Timeline tests

Cover:

- Trim boundaries
- Split source continuity
- Ripple
- Roll
- Slip
- Slide
- Snapping targets and thresholds
- Multi-selection transforms
- Layer reorder
- Work area
- Composition/layer markers
- Parent-cycle rejection
- Undo/redo round trips
- Exact-time stability across repeated edits

### 16.2 Effect-stack tests

Cover:

- Ordered evaluation
- Reorder changes graph order
- Enable/disable
- Delete restores pre-effect source semantics
- Parameter persistence
- Parameter animation at exact time
- Unknown/invalid effect rejection

### 16.3 AI effect tests

Cover:

- Cache key changes with source/model/digest/time/parameter/tier/resolution changes
- Current-frame priority
- Cancellation of obsolete requests
- Cached-frame reuse
- Depth effect changes output on a known fixture
- Deleting/disabling depth returns pre-effect output
- Cutout alpha behavior
- Preview fallback state is explicit
- Export does not silently fallback

### 16.4 Extract/Bake integration tests

Verify:

- Output is finalized and validated before document commit.
- New media and layer are inserted together.
- Layer timing matches source layer.
- `ProjectAIAsset` metadata references the correct source/output media.
- Undo returns the document to the pre-extract state.
- Failed/cancelled extraction leaves no partial document mutation.

### 16.5 Render tests

Verify deterministic ordering between effects, masks, transform, matte, and composite.

Add actual Metal/pixel tests where render behavior cannot be proven by graph shape alone.

### 16.6 Persistence tests

Verify:

- Schema 4 -> 5 migration.
- Save/close/reopen preserves timing, effects, keyframes, markers, work area, parent/matte relationships.
- Deterministic serialization remains stable.

### 16.7 UI tests

At minimum cover an iPad-landscape workflow and an iPhone compact workflow:

- Open project.
- Select layer.
- Scrub timeline.
- Add Depth Map effect.
- Observe computing/cached state transition.
- Disable/delete effect.
- Add/move keyframe.
- Perform trim/split.
- Confirm project revision and Viewer update.

## 17. Performance and resource rules

- No Core ML inference on the main actor.
- No full-document recomputation when only one frame/effect identity changes.
- Avoid unbounded frame/result caches.
- Reuse existing Metal texture/resource pools where compatible.
- Timeline scrolling/zooming must not synchronously decode or infer media.
- Preview frame requests should be cancellable/debounced/coalesced during fast scrubbing.
- AI model loading should be centralized and reused, not performed independently by each SwiftUI view.

Performance claims must be backed by measured evidence on actual supported Apple hardware or CI-equivalent tests where appropriate. 9.0 does not claim After Effects or desktop GPU parity.

## 18. Release gate and IPA

The 9.0 release gate includes at least:

1. `xcodebuild -list` succeeds for the generated Xcode project/workspace.
2. Affected Swift package/unit tests pass.
3. Timeline, project migration, composition, render, Metal, AI, and app tests pass.
4. iPad and iPhone Simulator UI/startup coverage passes where CI supports it.
5. Native AI model audit and required inference regression tests pass.
6. Metal shaders compile into the app bundle.
7. iOS 17+ arm64 Release app build succeeds without changing signing/provisioning requirements.
8. Unsigned IPA packaging succeeds.
9. IPA inspection verifies:
   - `CFBundleDisplayName == Vertex2`
   - `CFBundleShortVersionString == 9.0.0`
   - `CFBundleVersion == 9`
   - expected existing bundle identifier
   - arm64 executable
   - no `_CodeSignature`
   - no `embedded.mobileprovision`
   - required `Assets.car`
   - required Metal library
   - required approved Core ML model bundles/manifests
10. SHA-256 is generated and recorded.

Final artifact name:

`Vertex2-9.0.0-unsigned.ipa`

No completion claim is allowed if the build, tests, artifact audit, or hash verification fail.

## 19. Non-goals for 9.0

The following remain future work unless strictly required to make the approved 9.0 slice correct:

- Full professional time-remapping/optical-flow engine.
- Full color-management/HDR/scopes suite.
- Full audio-studio feature set.
- Full text/vector engine.
- Complete general-purpose GPU effects catalog/preset ecosystem.
- Node compositor UI.
- Full 3D scene workspace.
- Expressions/automation system.
- Claiming all future roadmap phases are complete merely because the AE-style UI contains placeholders.

Controls for unimplemented future systems must not masquerade as working production features.

## 20. Acceptance criteria

Vertex2 9.0 is accepted only when all of the following are true:

- iPad landscape presents a coherent Project / Composition / Effect Controls / Timeline workspace rather than the old stacked-card editor as the primary editing experience.
- iPhone opens and edits the same project through a compact adaptation.
- The Layer Timeline performs real exact-time trim, split, snapping, multi-selection, and the required Phase 9 NLE edit operations through project commands.
- Existing transform/mask/matte animation is editable from timeline property rows.
- Depth Map, Cutout, Upscale, and Restore are real ordered layer effects, not detached file-picker-only utilities.
- Depth Map visibly affects the selected layer when enabled and immediately reveals pre-effect content when disabled/deleted.
- AI cache invalidation and current-frame scheduling react correctly to playhead and parameter changes.
- Extract/Bake creates a validated derived media asset and a new timeline layer atomically.
- Preview and export share effect semantics; export cannot silently hide missing AI results.
- Schema 4 projects migrate deterministically to schema 5 without losing Phase 8 content.
- Automated tests and the unsigned iOS Release artifact gate pass.
- The final audited file is `Vertex2-9.0.0-unsigned.ipa`.
