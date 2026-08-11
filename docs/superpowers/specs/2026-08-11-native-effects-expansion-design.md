# Vertex2 Native Effects Expansion Design

## Goal

Increase the executable Vertex2 effect catalog from 25 to at least 90 effects without presenting reference-only commercial plugin entries as exact implementations. Use the supplied 1,568-entry effects encyclopedia as a behavioral and UX reference, while implementing Vertex-owned algorithms and Apple Core Image/Metal processing from scratch.

## Legal and compatibility boundary

- Adobe default effect names may be used as compatibility labels where the implementation is a general image-processing operation.
- Commercial third-party plugin code, shaders, presets, assets, parameter layouts, trademarks-as-product-branding, and reverse-engineered binaries are not copied.
- Third-party entries such as Sapphire/Continuum/Red Giant remain reference entries unless Vertex2 has an independently implemented alternative.
- Vertex-owned alternatives use Vertex2 names and document only the broad behavioral inspiration. They do not claim pixel parity or binary/plugin compatibility.

## Architecture

### Effect model

Keep `ProjectEffect` persistence unchanged. Add new `ProjectEffectType` cases and descriptor metadata; parameters continue to use scalar/integer/boolean/text values so project schema 5 remains compatible.

Split the large descriptor set by adding `ProjectEffectExpansionDescriptors` in a focused source file. `ProjectEffectDescriptorRegistry.all` becomes the existing descriptors plus the expansion descriptors.

### Rendering

Keep the existing `NativeFrameEffectProcessor` as the stable entry point. Existing V16 effects remain on the current path. New effects are delegated to `NativeExpandedFrameEffectProcessor`, which has three execution styles:

1. direct built-in Core Image filters for well-defined operations such as Disc Blur, Zoom Blur, Unsharp Mask, photo looks, morphology, halftone, distortion, and tile effects;
2. deterministic Core Image filter chains for Vertex-owned effects such as Aura Glow, Dark Bloom, Edge Radiance, Halation, Film Grain, Scanlines, RGB Split, Prism Blur, Light Leak, and Sun Rays;
3. matte/composite chains for Luma Key, Bright Matte, and Dark Matte.

All output is cropped back to the source extent and passes through the same preview/export composition path as existing native effects.

### Performance

- Reuse the existing thread-local `CIContext` strategy.
- Avoid per-frame creation of large lookup tables or model assets.
- Generator images are cropped to source extent.
- High-cost blur/distortion/tile/custom-chain effects use the slower interactive preview cadence while the settled value and export remain full quality.
- No effect is marked implemented unless it can render a test frame on the iPad Simulator.

## Expansion set

### Blur & Sharpen

Disc Blur, Zoom Blur, Bokeh Blur, Unsharp Mask, Morphology Gradient, Morphology Minimum, Morphology Maximum, Morphology Rectangle Minimum, Morphology Rectangle Maximum.

### Color Correction / Channel

Temperature & Tint, Monochrome, Color Clamp, Photo Chrome, Photo Fade, Photo Instant, Photo Mono, Photo Noir, Photo Process, Photo Tonal, Photo Transfer, Linear to sRGB, sRGB to Linear, Color Threshold, Otsu Threshold.

### Stylize / Halftone

Crystallize, Edge Work, Gloom, Hexagonal Pixelate, Line Overlay, Pointillize, Circular Screen, Dot Screen, Hatched Screen, Line Screen, CMYK Halftone, Depth of Field.

### Distort

Bump Distortion, Linear Bump, Circle Splash, Circular Wrap, Droste, Hole Distortion, Light Tunnel, Pinch, Stretch Crop, Torus Lens, Vortex, Glass Lozenge.

### Tile

Kaleidoscope, Op Tile, Triangle Kaleidoscope, Sixfold Reflected Tile, Twelvefold Reflected Tile, Parallelogram Tile, Triangle Tile, Fourfold Reflected Tile, Fourfold Rotated Tile, Fourfold Translated Tile, Eightfold Reflected Tile, Glide Reflected Tile, Sixfold Rotated Tile.

### Vertex2 clean-room alternatives

Vertex Aura Glow, Vertex Dark Bloom, Vertex Edge Radiance, Vertex Halation, Vertex Film Grain, Vertex Scanlines, Vertex RGB Split, Vertex Prism Blur, Vertex Light Leak, Vertex Sun Rays.

The supplied encyclopedia describes glow-family effects as highlight/mask extraction followed by blur/radial/light processing and additive compositing. Vertex alternatives use only that general image-processing model, with independent code and controls.

### Keying / Matte

Luma Key, Bright Matte, Dark Matte.

## UI

The descriptor-driven Effect Controls UI continues to generate controls automatically. Add `Tile` and `Keying` categories. Effects & Presets shows the true implemented count. Third-party reference entries remain labeled INDEXED unless a separate Vertex-owned alternative is selected from the Vertex2 group.

## Testing

1. Portable tests verify descriptor completeness, unique effect types, valid defaults, new categories, and at least 90 executable effects.
2. iPad app tests instantiate every native effect with default parameters and render a small deterministic test image through `NativeFrameEffectProcessor`; any unavailable filter, invalid key, missing parameter, or nil output fails release qualification.
3. Tests verify AI-only effects remain excluded from native processing and future native additions no longer require exhaustive AI-bake switch edits.
4. Compatibility tests preserve the 1,568-entry reference count and distinguish executable Vertex effects from reference-only items.

## Release boundary

This expansion is developed on `agent/phase16-effects-expansion` from verified V16 HEAD `7ee1347232899afa36d562fe220aca0adf9f25ee`. It does not change project schema 5. A release build is only produced after portable and iPad Simulator render coverage pass.