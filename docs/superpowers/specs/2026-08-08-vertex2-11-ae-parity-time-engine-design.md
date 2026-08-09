# Vertex2 11.0 AE Parity + Time & Animation Engine Design

Date: 2026-08-08
Branch: `agent/phase11-ae-time-engine-spec`
Base: verified Vertex2 10.0 HEAD `17359ae54945c92715b3631f4389a0143c245f98`
Target: Vertex2 11.0.0 build 11, iPadOS 17+, iPad-only landscape, unsigned release artifact

## 1. Product direction

Vertex2 11.0 changes the UI target from merely "AE-style" to current After Effects workflow/function parity wherever the corresponding Vertex feature exists. The goal is that an experienced After Effects user can transfer their mental model, panel workflow, timeline semantics, property hierarchy, keyframe workflow, graph editing habits, project/composition lifecycle, and keyboard/trackpad expectations directly to Vertex2 with minimal relearning.

Vertex branding remains independent. Adobe trademarks, logos, splash artwork, icons, and proprietary visual assets must not be copied. The user-provided `Vertex. STUDIO` artwork is the sole source of truth for the app icon and Vertex Studio launch/home identity. The product may reproduce interaction patterns, information architecture, and editing semantics, but must retain Vertex names and artwork where brand identity is involved.

11.0 must not ship fake controls. A control is present only when its data path is real or when it is an explicitly informative state such as unavailable/unsupported. Future Color, Expression, Tracking, Paint, Particle, and later roadmap engines stay scheduled for later releases instead of being represented as working 11.0 functionality.

## 2. Release scope

11.0 implements the full approved Time & Animation scope in one release:

- unified animation property core for numeric, vector, color, transform, effect, camera, light, 3D, audio, and time-remap properties
- AE-like keyframe/property timeline and disclosure hierarchy
- Value Graph and Speed Graph editor
- temporal and spatial interpolation, velocity, influence, easing, Bezier, Hold, Continuous/Auto Bezier, and roving keyframes where semantically valid
- gesture/motion recording using touch and Apple Pencil that resolves to normal editable keyframes
- professional velocity/time operations including Time Remap, Freeze, Reverse, stretch, variable ramps, source-time mapping, and nested composition time mapping
- Frame Mix and real optical-flow frame interpolation with fail-closed error semantics
- audio retiming with pitch-preserve option and audio/video synchronization guarantees
- BPM grid, subdivisions, markers, and keyframe snapping
- startup/loading, Home, New/Open Project, recent-project lifecycle, recovery, and workspace persistence
- current-AE-like workspace/panel system including Project, Composition, Effect Controls, Effects & Presets, Timeline, Graph Editor, Preview, Info, Audio, Align, Character, and Paragraph panels
- project/composition creation flow redesigned to match the AE mental model
- user-provided Vertex Studio image used for app icon generation and launch/home branding
- 11.0 regression and release qualification ending in `Vertex2-11.0.0-unsigned.ipa`

Team Project is excluded from 11.0. No placeholder Team Project button is shown because real collaboration requires backend/synchronization infrastructure outside this release.

## 3. Launch and startup architecture

The application begins with a Vertex Studio startup surface modeled on the pacing and information density of a professional After Effects launch experience, while using only Vertex branding and user-provided artwork.

Startup progress is not decorative. Each visible state maps to a real subsystem transition. The startup state machine is:

`coldStart -> loadingServices -> restoringSession -> ready`

and may terminate in either:

`recoverableFailure` or `fatalFailure`.

Subsystems include project services, persistence/recovery scan, renderer initialization, effects registry, AI model registry, workspace restoration, and required runtime capability checks. Slow optional subsystems must never hold the entire app in an indefinite loading state. A failed AI model, unavailable optional service, corrupt recent-project entry, or non-critical workspace restore failure must degrade only the affected feature whenever possible.

Startup tasks must be cancellable/timeout-aware where applicable and must have explicit terminal outcomes. The previous class of infinite-loading failures is a release blocker.

## 4. Home and project lifecycle

After startup the app enters a Home surface instead of immediately synthesizing an Untitled composition. Home exposes:

- Home
- New Project
- Open Project
- Recent Projects

Recent projects display name, thumbnail when available, path/location context, and last-modified metadata. Missing recent items surface a recoverable `Project Not Found` state and may be removed from the list without blocking launch.

`New Project` creates an empty writable `.vertexproject`. Project creation does not implicitly create a composition. This requires changing the current new-project lifecycle while maintaining compatibility with old projects through migration/read logic.

`Open Project` uses the iPad document/file flow, validates the package, runs supported migrations, resolves media references, restores project UI/session state when valid, and terminates in a visible success or failure state.

Project opening follows:

`opening -> validating -> migrating -> resolvingMedia -> ready`

or `failed`.

Unsaved-close behavior, Save, Save As, recent-project registration, autosave, recovery, and crash-recovery prompts are part of the lifecycle contract.

## 5. New Composition workflow

A new project is empty until the user creates a composition or creates one from footage. The New Composition dialog follows the current AE mental model and exposes real values rather than cosmetic fields:

- composition name
- preset
- width and height
- aspect-ratio lock
- pixel aspect ratio
- frame rate
- resolution
- start timecode/start frame
- duration
- background color
- basic/advanced settings
- renderer/3D-related settings that are genuinely supported by Vertex
- supported motion-blur/composition timing options
- custom preset save and recent/custom preset reuse

Preset selection must update the actual project model. Composition settings must be consumed by preview and export rather than remaining view-local state.

## 6. Workspace system

11.0 replaces the current responsive grid concept with a real dockable workspace model. Panel behavior must support the professional editing semantics expected from AE:

- resize
- tab
- stack
- split
- collapse
- close/reopen
- maximize/restore
- dock/undock within iPad window constraints
- save workspace
- reset workspace
- restore workspace safely after relaunch

The default editing workspace follows the current AE information architecture at high density:

- Project at upper left
- Effects & Presets below/alongside Project
- Composition Viewer central
- Effect Controls on the right
- Timeline/Graph Editor across the lower workspace
- auxiliary panels grouped in tabs or stacks according to available width

Stage Manager and narrow-window behavior must collapse or tab lower-priority panels rather than crushing text/buttons vertically. The previous 10.0 issue where actions wrapped into unusable vertical labels is a release blocker.

## 7. Core panels

### Project

The Project panel is a real project item tree with folders, compositions, imported footage, search/filter, item selection, rename, remove, and create/import commands. It must represent authoritative project content rather than a disconnected browser UI.

### Composition Viewer

The Composition viewer exposes supported zoom, resolution/quality, channel/view controls, grid/safe-area controls, overlays, viewer tabs, and direct manipulation. Viewer changes that affect rendering must use the same underlying state consumed by preview/export where appropriate.

### Effects & Presets

The 10.0 Offline AI Studio takeover is removed. Effects & Presets becomes a searchable hierarchy. Only effects with real implementations are shown as working effects. AI becomes one category containing currently implemented Depth Map, Cutout, Upscale, and Restoration paths.

Effects can be applied through drag/drop or equivalent direct action, appear in Effect Controls, expose animatable parameters, and flow to preview/export.

### Effect Controls

Effect Controls represents the selected layer's transform and applied effect stack. Parameter edits are project edits. Animatable parameters use the unified animation property system and expose stopwatch/keyframe controls.

### Auxiliary panels

11.0 implements usable Preview, Info, Audio, Align, Character, and Paragraph panels. Libraries/cloud collaboration is omitted until it has real infrastructure.

Preview controls playback, stepping, looping, and audio preview. Info shows relevant coordinates/color/item metadata. Audio shows supported level/property information. Align performs real alignment/distribution. Character and Paragraph edit real text-layer properties.

## 8. AE-like Timeline

The existing simplified slider-style timeline is replaced.

The timeline consists of a left layer/property region and right time region with a resizable divider. Layer rows expose supported AE-like switches and columns including visibility/audio, solo, lock, shy, 3D, motion blur, adjustment semantics where supported, blend mode, Track Matte, Parent & Link, labels, in/out range, and layer names.

The time region contains a ruler, current-time indicator, work area, layer bars, in/out handles, markers, keyframes, selection, and snapping.

Layer disclosure reveals real property hierarchies such as:

- Transform
- Effects
- Masks
- Time Remap
- supported audio/text/3D property groups

The timeline must support reorder, duplicate, trim, layer selection, property expansion, keyframe creation/deletion/move/copy/paste, and Undo/Redo using real project commands rather than local-only state.

## 9. Unified Animation Core

Every animatable property uses a common typed animation abstraction rather than bespoke per-feature keyframe implementations. The core must support at least scalar, 2D/3D vector, color, angle/rotation, opacity-like scalar, and source-time properties, with extension points for later releases.

A property may be static or animated. Animated properties own ordered keyframes at exact `RationalTime` values. Keyframes contain value and interpolation metadata appropriate to the property type.

Temporal interpolation supports:

- Linear
- Hold
- Bezier
- Easy Ease
- Ease In
- Ease Out
- incoming/outgoing velocity
- incoming/outgoing influence
- Continuous Bezier
- Auto Bezier

Spatial properties support spatial tangents and path interpolation. Roving keyframes are supported where valid.

Animation evaluation must be deterministic, frame-rate-independent at the model level, and shared by Timeline, Graph Editor, Preview, and Export.

## 10. Graph Editor

The Graph Editor is another editor for the same animation data, never a second animation store.

It provides:

- Value Graph
- Speed Graph
- multi-property display/selection
- keyframe handles
- velocity/influence editing
- graph zoom/pan
- value/speed scaling
- interpolation/easing changes
- keyframe selection and movement
- appropriate spatial/temporal graph representations

Graph edits must immediately change the same project keyframes evaluated by the composition renderer. A graph that visually differs from actual playback is a release blocker.

## 11. Gesture Recording and Motion Sketch

Touch and Apple Pencil input can record motion over time. Samples are timestamped using exact project/composition time, filtered for noise, simplified, and fitted to editable spatial curves. The final result is ordinary Position/Rotation/Scale keyframes, not a proprietary hidden recording track.

Recording provides configurable smoothing/simplification so normal motion does not leave thousands of redundant keyframes. Recording edits participate in Undo as coherent operations.

## 12. Professional time remapping and velocity

Source time becomes an animatable property for media and supported nested compositions. This unified mapping drives:

- speed changes
- slow/fast motion
- Reverse
- Freeze Frame
- freeze at current frame
- Time Remapping
- variable speed ramps
- time stretch
- hold segments
- source in/out retiming
- supported loop/ping-pong Vertex utilities
- nested composition time mapping

Time-remap evaluation is exact and deterministic. Preview and export resolve source frames using the same mapping implementation.

## 13. Frame interpolation

11.0 supports two explicit frame interpolation modes where applicable:

- Frame Mix: interpolation/blending between neighboring frames
- Optical Flow: motion-estimation-based intermediate-frame synthesis

Optical Flow is a real backend, not a label over frame blending. It must expose explicit failure semantics. If motion estimation cannot safely produce a frame, the system must surface/fallback according to a defined policy rather than silently emitting corrupted frames.

The initial implementation must be performance-aware on iPad and remain bounded under memory/thermal pressure.

## 14. Audio retiming and BPM

Retimed media maintains audio/video synchronization. The user can choose Pitch Preserve. When enabled, time changes attempt to preserve perceived pitch; when disabled, pitch follows playback speed.

BPM support includes:

- composition/project BPM value
- beat grid
- subdivisions
- beat snapping
- marker generation
- keyframe snapping to beats

Automatic BPM detection is not promised in 11.0 unless a validated implementation is added during development. No fake automatic-detection control ships.

## 15. Exact time contract

Internal editing time uses the existing exact `RationalTime` model. `Double` seconds may be used only for presentation/adapters where unavoidable and must not become the authoritative time representation.

11.0 explicitly verifies 24, 25, 23.976/29.97/59.94-style rational rates, 30, 50, 60, and supported custom rates. Long-duration keyframes, nested compositions, time remapping, preview, and export must not drift across frame boundaries.

A keyframe at a specific timeline frame evaluating to a different final export frame is a release blocker.

## 16. Renderer data flow

The target flow is:

`Project -> Animatable Properties -> Animation Evaluator(time) -> Resolved Layer/Effect State -> CompositionGraphCompiler -> Metal Render Backend -> Preview / Export`

Preview and Export must share evaluator semantics. No simplified preview-only animation path is allowed.

Effects, transforms, masks, cameras/lights/3D properties, and future engine properties should be able to register with the animation system without reimplementing timeline infrastructure.

## 17. Recovery and failure semantics

Project recovery uses autosave/recovery snapshots with user choices such as Recover Project, Open Original, or Discard Recovery when appropriate.

The application must never remain indefinitely in a generic loading state because a project, model, effect, workspace, or optional service failed. Recoverable failures isolate the affected subsystem and provide a path back to a usable app when possible.

Optical flow, pitch processing, media resolution, project migration, workspace restoration, and AI model loading must all have explicit terminal outcomes and testable error surfaces.

## 18. App icon and Vertex Studio artwork

The user-provided first reference image, `Vertex. STUDIO`, is the authoritative source artwork for the 11.0 app icon. AppIcon assets must be generated from that exact source image with appropriate iOS sizing/cropping behavior and without replacing it with generated AE-like branding.

The same identity is used on launch/home surfaces in a layout appropriate for the screen. The app icon is not simply stretched as a splash image.

Existing temporary AE-shaped or placeholder Vertex icons are removed from the 11.0 release identity.

## 19. Compatibility and migration

11.0 must open supported 10.0 and earlier Vertex projects without destructive rewriting before validation/migration succeeds. The new empty-project creation flow does not invalidate existing projects that already contain a default/main composition.

If schema changes are required for unified animation/time mapping, the migration is deterministic and covered by fixtures. Migration failure must preserve the original package.

## 20. Testing strategy

Portable tests cover animation interpolation, exact-time evaluation, graph/value-speed conversions, keyframe ordering, source-time mapping, Reverse/Freeze/ramp behavior, BPM snapping, migration, and deterministic project encoding.

iPad Simulator tests cover Home/New/Open Project, New Composition, panel layout, workspace persistence/reset, Timeline interactions, Graph Editor operations, effect parameter keyframes, auxiliary panels, gesture recording adapters, and critical startup/recovery states.

Apple-native tests cover renderer parity, media retiming, Frame Mix, Optical Flow backend behavior/failure semantics, audio pitch-preserve synchronization, and relevant Metal/AVFoundation paths.

Regression tests retain the verified 10.0 AI, 3D, persistence, composition, export, and arm64 release checks.

## 21. Release blockers

The following conditions block Vertex2 11.0 release:

- any infinite loading/startup/project-open state
- Timeline controls that are cosmetic or disconnected from project data
- Graph Editor curve not matching evaluated animation
- Preview and Export producing different easing/time-remap results
- one-frame drift in deterministic exact-time cases
- corrupted or silently wrong Optical Flow output
- audio/video desynchronization from retiming or Pitch Preserve
- project migration that can destroy the original on failure
- keyframe edits lost after save/reopen
- Undo/Redo partially restoring grouped keyframe edits
- panel compression that renders primary controls unusable in supported iPad/Stage Manager widths
- unsupported/future features presented as working controls
- app icon not generated from the user-provided Vertex Studio source

## 22. Release qualification and artifact

11.0 is complete only when all required tests pass on the final commit and the release workflow successfully produces an unsigned iOS 17+ arm64 artifact.

The final release gate includes:

- portable Swift tests
- AI/model/license audits inherited from 10.0
- native Time/Animation/Optical Flow/audio tests
- iPad Simulator app tests
- native Metal/AVFoundation compilation and tests
- unsigned iOS arm64 Release build
- bundle identity/version/device-family/orientation inspection
- app icon/resource inspection
- strict IPA audit
- independent unpacked IPA verification
- SHA-256 verification

Target artifact: `Vertex2-11.0.0-unsigned.ipa`.

No completion claim is made before the final IPA is independently inspected and its checksum is verified.

## 23. Explicit non-goals for 11.0

The following remain later-roadmap work unless already supported and merely integrated here:

- full professional color-management engine planned for 12.0
- expression engine planned for 13.0
- full Render Queue expansion planned for 14.0
- later large effect-family expansions
- universal tracking, advanced matte/keying, content-aware paint/inpainting, particle/simulation systems
- cloud Libraries or Team Project collaboration backend

11.0 focuses on making the current application lifecycle/workspace feel AE-familiar while establishing a production-grade animation/time foundation that later releases can reuse.
