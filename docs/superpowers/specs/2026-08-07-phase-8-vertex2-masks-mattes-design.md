# Phase 8 Vertex2 Masks & Mattes Design

Date: 2026-08-07
Branch: `agent/phase-8-vertex2-motion-masks`
Base commit: `1f471ffede1a28a6e7934c5ae1f392490663a102`

## Product goal

Ship `Vertex2 8.0.0` as a real layer-based compositor increment, not a visual mock. The app keeps the existing exact-time project/persistence/render architecture and adds the Motion Engine subset required by masks: reusable typed keyframe channels, animated layer transforms/opacity, animated mask paths/parameters, GPU vector-mask evaluation, and alpha/luma track mattes.

The user-facing app name becomes `Vertex2`. Internal module names remain `Vertex*` so a branding change does not trigger an unrelated engine rename. Bundle identifier remains `com.woo642778.aftereffects`.

## Branding

- `CFBundleDisplayName`: `Vertex2`
- `PRODUCT_NAME`: `Vertex2`
- marketing/build: `8.0.0 (8)`
- final unsigned artifact: `Vertex2-8.0.0-unsigned.ipa`
- app icon source: the user-supplied photo showing a crouching person beside a cat; crop and resize only, no generated replacement subject and no text overlay
- splash/loading screen: dark Vertex2 wordmark treatment, short cosmetic transition only; startup completion must never depend on AI/model/Metal/project readiness

## Animation model

Each `ProjectLayer` stores ordered `animationChannels`. A channel has a stable `VertexID`, typed `ProjectPropertyAddress`, and exact-time keyframes. Keyframes have stable IDs and support Hold, Linear, and cubic Bezier temporal interpolation.

`ProjectAnimatableValue` supports scalar, vector2, color, boolean, and Bezier-path values so the channel abstraction is reusable later. Phase 8 consumes scalar and Bezier-path values directly. Value type must remain consistent inside a channel.

Property addresses used in 8.0:

- layer Position X/Y
- Anchor X/Y
- Scale X/Y
- Rotation
- Opacity
- mask Opacity
- mask Feather
- mask Expansion
- mask Path

Before-first/after-last evaluation clamps to endpoint keys. Duplicate keyframe times, non-finite numbers, mismatched path topology, and mismatched value types are rejected.

## Mask model

Each `ProjectLayer` stores ordered `masks` with stable ID, name, cubic Bezier path, mode, opacity, feather pixels, signed expansion pixels, invert, enabled.

Modes: Add, Subtract, Intersect, None.

Bezier vertices store anchor, incoming tangent and outgoing tangent in normalized layer-local coordinates. Mask path animation interpolates corresponding vertices/tangents when topology matches.

Mask semantics run before the layer transform so a mask stays attached to the layer. CPU work may flatten cubic paths into deterministic line segments; final pixel coverage and combination occur in Metal.

## Track mattes

A pixel-producing layer may consume another **media or nested-composition layer** in the same composition as a track matte:

- Alpha
- Alpha Inverted
- Luma
- Luma Inverted

The matte source is rendered using its own source, effects, masks and transform but is not separately composited when consumed as a matte. Matte references must exist, remain in the same composition, reference another media/nested-composition layer, not self-reference, and form no cycles. Adjustment and model-only layers cannot serve as matte sources in Phase 8 because their semantics depend on the current accumulator rather than a standalone source texture.

Luma coverage uses Rec.709 coefficients on straight RGB and is multiplied by matte alpha. Inverted modes use `1 - coverage`.

## Render architecture

`CompositionGraphCompiler` evaluates animation at exact `RationalTime`, prepares per-layer render nodes, applies masks before transform/effects, applies track matte after source transform/effects, then composites the resulting layer into the accumulator.

`VertexRender` adds two node kinds:

- `.mask(RenderMaskStack)` — one input, GPU mask coverage/application
- `.matte(RenderTrackMatteMode)` — ordered `[source, matte]` inputs

`RenderMaskStack` contains deterministic flattened segments and mask parameters. The graph stays Codable so cache keys include mask/matte semantics.

`MetalGraphExecutor` executes both nodes. `vertexMaskKernel` computes inside/outside and minimum segment distance in pixel space, applies expansion/feather/opacity/invert and ordered Add/Subtract/Intersect semantics, then multiplies coverage into premultiplied source color/alpha. `vertexMatteKernel` derives alpha/luma coverage from the matte texture and multiplies the source.

No Core Image or CPU pixel-mask fallback is allowed.

## Editor behavior

The existing Composition workspace remains the editing surface and gains:

- keyframe button for Position X/Y, Scale X/Y, Rotation, Opacity
- interpolation control and key list sufficient to add/delete keys at the current exact frame
- mask list with add rectangle/ellipse, delete/reorder, mode/invert, opacity/feather/expansion
- mask path editor with draggable vertices and tangent handles over the real rendered preview coordinate system
- mask Path keyframe control
- track-matte source/mode controls

Every UI mutation routes through `ProjectCommandPayload` / `ProjectCommandEngine`, preserving Undo/Redo/autosave validation.

## Persistence

Advance canonical project schema from 3 to 4. Add deterministic `Schema3To4Migrator` that initializes empty animation/mask/matte state while preserving every existing field and AI asset. Update current app version to `8.0.0`.

Schema-3 packages remain readable through the migrator. Canonical output remains sorted and deterministic.

## Validation

Reject:

- duplicate mask/channel/keyframe IDs
- duplicate keyframe times within a channel
- non-finite scalar/path/handle values
- invalid transform scale/opacity after animation evaluation
- mask opacity outside 0...1 or negative feather
- path with too few vertices or excessive vertex/flattened-segment count
- animated path topology mismatch
- property/value type mismatch
- mask property address referencing a missing mask
- invalid matte source, self reference, cross-composition reference, model-only source, adjustment-layer source, or matte cycle

## Limits

To keep mobile cost bounded:

- maximum masks per layer: 16
- maximum Bezier vertices per mask: 64
- deterministic cubic flattening: 8 line segments per Bezier edge
- maximum flattened segments per mask: 512

These are validation limits, not silent truncation.

## Verification gate

8.0 is complete only after:

- portable project/animation/mask tests pass
- schema 3→4 deterministic migration tests pass
- composition compiler tests prove exact-time animated transform/mask and matte graph construction
- Metal pixel tests prove Add/Subtract/Intersect, invert, feather/expansion, animated mask frame differences, alpha/luma/inverted matte behavior
- existing Phase 7 AI native inference tests remain green
- iOS Simulator app tests and startup/session tests pass
- unsigned iOS 17 arm64 Release build passes
- final IPA contains Vertex2 branding, icon resources, AI models and Metal library, with no signature/provisioning profile
- exact SHA-256 is independently calculated

No AE/Alight Motion/Topaz quality parity claim is made without a separate benchmark.
