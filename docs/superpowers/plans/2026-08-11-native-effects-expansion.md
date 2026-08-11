# Native Effects Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase Vertex2 from 25 to 99 executable effects while keeping commercial reference entries honest and implementing plugin-like alternatives with independent Vertex-owned processing.

**Architecture:** Preserve `ProjectEffect` schema 5 and the descriptor-driven UI. Add 74 native cases and descriptors in focused expansion files, delegate new rendering from `NativeFrameEffectProcessor` to `NativeExpandedFrameEffectProcessor`, and qualify every native default by rendering a real test image on an iPad Simulator.

**Tech Stack:** Swift 6, Core Image, Core Graphics, Swift Testing, existing VertexProject/VertexComposition renderer.

## Global Constraints

- Base commit: `7ee1347232899afa36d562fe220aca0adf9f25ee`.
- Branch: `agent/phase16-effects-expansion`.
- Project schema remains 5.
- iPad only, iOS/iPadOS 17.0 minimum.
- No copied third-party code, shaders, presets, assets, or proprietary parameter layouts.
- Third-party encyclopedia entries remain reference-only unless a distinct Vertex-owned alternative exists.
- No effect is counted as executable until the iPad render smoke test succeeds.

---

### Task 1: Add failing expansion contract tests

**Files:**
- Create: `Tests/VertexProjectTests/Phase16ExecutableEffectsExpansionTests.swift`
- Create: `Tests/VertexAppTests/NativeExpandedEffectsRenderTests.swift`

**Interfaces:**
- Consumes: `ProjectEffectType.allCases`, `ProjectEffectDescriptorRegistry.all`, `NativeFrameEffectProcessor.process(_:)`.
- Produces: release contract requiring exactly 99 effect types, descriptor completeness, and real default-frame rendering for all native types.

- [ ] Add a portable test asserting `ProjectEffectType.allCases.count == 99`, descriptor types equal declared types, descriptor defaults validate, and new `tile`/`keying` categories exist.
- [ ] Add an app test that generates a small RGBA PNG, wraps it in `PortableImage`, constructs a `CompositionEffectRequest` for every `isNativePixelEffect` type, and requires non-empty output with the same pixel size.
- [ ] Push tests before production code and confirm Phase Validation fails because the 74 new cases are absent.

### Task 2: Expand the effect model and metadata

**Files:**
- Modify: `Sources/VertexProject/ProjectEffect.swift`
- Modify: `Sources/VertexProject/ProjectEffectDescriptor.swift`
- Create: `Sources/VertexProject/ProjectEffectExpansionDescriptors.swift`

**Interfaces:**
- Produces: 74 new `ProjectEffectType` cases; `ExpandedEffectParameterID`; descriptors for each new type.

- [ ] Add the 74 cases listed in the design spec.
- [ ] Simplify native classification so only the four AI types are non-native.
- [ ] Add `tile` and `keying` categories with user-facing names.
- [ ] Add shared scalar parameter IDs: `radius`, `amount`, `angle`, `scale`, `centerX`, `centerY`, `width`, `height`, `threshold`, `softness`, `intensity`, `frequency`, `sharpness`, `temperature`, `tint`, `levels`, `count`, `rotation`, `decay`, `mix`, `contrast`, `saturation`.
- [ ] Define one descriptor per new case with valid defaults and bounded domains.
- [ ] Append expansion descriptors to `ProjectEffectDescriptorRegistry.all`.

### Task 3: Implement direct Core Image effects

**Files:**
- Create: `App/NativeExpandedFrameEffectProcessor.swift`
- Modify: `App/NativeFrameEffectProcessor.swift`

**Interfaces:**
- `NativeExpandedFrameEffectProcessor.filteredImage(effect:input:) throws -> CIImage?` returns nil for legacy/AI effects and a rendered image for every expansion type.

- [ ] Implement Blur & Sharpen filters using `CIDiscBlur`, `CIZoomBlur`, `CIBokehBlur`, `CIUnsharpMask`, and morphology filters.
- [ ] Implement color/photo filters using `CITemperatureAndTint`, `CIColorMonochrome`, `CIColorClamp`, photo-effect filters, tone-curve conversions, and threshold filters.
- [ ] Implement stylize/halftone filters using crystallize, edge work, gloom, hexagonal pixelate, line overlay, pointillize, screen/halftone filters, and depth of field.
- [ ] Implement distortion filters using bump, splash, wrap, Droste, hole, light tunnel, pinch, stretch, torus, vortex, and glass-lozenge filters.
- [ ] Implement tile filters using kaleidoscope and the selected reflected/rotated/translated tile family.
- [ ] Delegate expansion cases before the existing V16 switch and use a default error path so the legacy switch no longer needs every future native case enumerated.

### Task 4: Implement Vertex clean-room composite effects

**Files:**
- Modify: `App/NativeExpandedFrameEffectProcessor.swift`

**Interfaces:**
- Produces independent filter chains for ten Vertex-owned effects.

- [ ] `Vertex Aura Glow`: threshold highlights, multi-scale Gaussian bloom, additive/screen composition.
- [ ] `Vertex Dark Bloom`: derive dark-region mask, blur the contribution, and composite without copying any third-party shader.
- [ ] `Vertex Edge Radiance`: edge extraction -> bloom -> additive composite.
- [ ] `Vertex Halation`: isolate highlights, blur a warm red-biased contribution, blend at controlled intensity.
- [ ] `Vertex Film Grain`: crop `CIRandomGenerator`, neutralize/chroma-limit noise, and blend with the source.
- [ ] `Vertex Scanlines`: generate stripes at user frequency and multiply/mix against source.
- [ ] `Vertex RGB Split`: isolate RGB channels with `CIColorMatrix`, translate channels in opposite directions, and add them.
- [ ] `Vertex Prism Blur`: RGB split followed by controlled Gaussian blur and screen/add blend.
- [ ] `Vertex Light Leak`: generate a radial gradient near the selected normalized center, tint it warm, blur, and screen over source.
- [ ] `Vertex Sun Rays`: use `CISunbeamsGenerator`, crop to source extent, and screen with source.

### Task 5: Implement matte/key effects

**Files:**
- Modify: `App/NativeExpandedFrameEffectProcessor.swift`

**Interfaces:**
- Produces `Luma Key`, `Bright Matte`, and `Dark Matte` without a new persistence value type.

- [ ] Build a grayscale luminance image with `CIColorControls` saturation 0.
- [ ] Threshold with `CIColorThreshold`, optionally invert for dark matte/key behavior.
- [ ] Convert masks through `CIMaskToAlpha`.
- [ ] For Luma Key, composite the original image over clear background using the generated mask.
- [ ] For Bright/Dark Matte, output a visible grayscale/alpha matte suitable for subsequent layer workflows.

### Task 6: Future-proof AI and UI switches

**Files:**
- Modify: `App/AIEffectBakeCoordinator.swift`
- Modify: `App/BundledAIEnvironment+FrameEffects.swift`
- Modify: `App/EffectsAndPresetsView.swift`
- Modify: `App/AIEffectControlsView.swift`

**Interfaces:**
- Future native cases must not break AI switch exhaustiveness.

- [ ] Replace lists of native cases in AI-only switches with guarded default rejection.
- [ ] Replace exhaustive per-effect icon mapping with AI-specific icons plus category-derived native icons.
- [ ] Add expansion-heavy effects to the low-frequency interactive-preview tier (blur, morphology, halftone, distortion, tile, and Vertex composite effects).
- [ ] Keep the header count driven by descriptors so it reports 99 implemented automatically.

### Task 7: Verify red-to-green and release readiness

**Files:**
- Modify tests only if a test itself is incorrect; never weaken count/render coverage to hide failures.

- [ ] Run portable Swift tests and fix descriptor/model errors.
- [ ] Generate the Xcode project and run all `VertexAppTests` on the newest iPad Simulator.
- [ ] Require every native default effect to produce output; if a Core Image filter is unavailable or parameter keys differ on iPadOS 17, replace that implementation with a supported independent chain rather than marking it implemented.
- [ ] Run existing AI model/tooling audit to ensure the expansion does not disturb the four AI effects.
- [ ] Run Phase Validation on the final HEAD and record the exact executable count.
