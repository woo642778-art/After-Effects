# Phase 4 GPU Render Graph Design

## Goal

Build the first production render vertical slice for After Effects 4.0.0: a Vertex-owned semantic render graph evaluated by a native Metal backend, with the same graph result used for on-screen preview and PNG file output.

## Product boundary

Phase 4 is not a timeline, playback engine, multilayer compositor, full export system, effect catalog, motion system, color grader, tracker, AI system, shape engine, node editor, or 3D renderer. It establishes the contracts those systems will use.

## Architecture

### VertexRender

A platform-neutral Swift module owns:

- render graph identity and topology;
- exact render time using `RationalTime`;
- source image references;
- ordered operations;
- output dimensions and color metadata;
- deterministic cache keys;
- cancellation and back-pressure policy;
- structured validation and execution errors;
- backend protocol boundaries.

No `Metal`, `MetalKit`, `CoreImage`, `UIKit`, `SwiftUI`, `AVFoundation`, `MetalPetal`, or `VideoIO` type may escape into this module.

### VertexRenderMetal

An Apple-platform module owns:

- Metal device and command queue lifetime;
- PNG/JPEG decoding into RGBA textures;
- texture allocation and reuse within one render request;
- GPU compute execution;
- readback into a portable PNG result;
- CPU, GPU, and total timing metrics;
- cancellation checks before submission and after command completion;
- backend-specific errors mapped to `RenderError`.

### Application integration

The Phase 3 media importer remains the source of decoded thumbnail data. Once a movie has a thumbnail, the app exposes a Render Lab with controls for:

- exposure in stops;
- saturation;
- opacity;
- inversion;
- output size preset.

The app sends one `RenderRequest` to `VertexRenderMetal`. The returned PNG bytes are displayed as preview. Export writes those exact bytes to a user-selected location, proving preview and file output share one semantic and executable path.

## Semantic graph

The Phase 4 graph supports one image source followed by an ordered operation list:

1. affine transform using normalized translation and scale;
2. exposure;
3. saturation;
4. inversion;
5. opacity over transparent black;
6. output resize.

The model is intentionally linear in Phase 4 but uses stable node IDs and dependency validation so Phase 6 layers and Phase 21 free-form nodes can reuse it.

## Core types

- `RenderGraph`
- `RenderNode`
- `RenderNodeKind`
- `RenderOperation`
- `RenderRequest`
- `RenderOutputSpecification`
- `RenderResult`
- `RenderMetrics`
- `RenderCacheKey`
- `RenderBackend`
- `RenderCancellationToken`
- `RenderBackPressurePolicy`
- `RenderError`

## Validation rules

- A graph must contain exactly one output node.
- Every referenced dependency must exist.
- Cycles are rejected before backend execution.
- The source image must be non-empty PNG or JPEG data.
- Width and height must be positive and bounded to 8192 pixels per dimension in Phase 4.
- Scale must be finite and greater than zero.
- Translation, exposure, saturation, and opacity must be finite.
- Saturation is clamped to 0...4 at execution.
- Opacity is clamped to 0...1 at execution.
- Output color metadata is explicit and defaults to sRGB/Rec.709 SDR with straight alpha.

## Metal implementation

A single Metal compute kernel reads RGBA8 input and writes RGBA8 output. For each output pixel it:

- maps the output coordinate through inverse scale and normalized translation;
- samples the input texture with a linear clamp-to-zero sampler;
- applies exposure with `pow(2, stops)`;
- converts RGB to luma and applies saturation;
- optionally inverts RGB;
- multiplies RGBA by opacity;
- writes the result.

The shader is bundled in the application target and loaded through the default Metal library. The backend does not maintain a second CPU effect implementation.

## Preview and export parity

The app preview displays `RenderResult.image.data`. PNG export writes the same byte sequence. There is no separate export renderer. Tests verify byte identity for the app-level preview/export handoff and pixel agreement for deterministic fixtures.

## Source adoption decision

### MetalPetal

- License: MIT.
- Phase 4 decision: audited candidate, not linked into the product target.
- Reason: Vertex first needs stable internal graph, color, time, cancellation, and result contracts. MetalPetal can later implement additional kernels behind `RenderBackend` without changing project models.

### VideoIO

- License: MIT.
- Phase 4 decision: audited candidate, not linked into the product target.
- Reason: Phase 3 already owns media decoding through an AVFoundation adapter. VideoIO remains a later preview/export utility candidate once continuous playback and video-file export exist.

## Error handling

`RenderError` distinguishes invalid graph, missing node, cycle, invalid request, unsupported image, unavailable Metal device, shader loading failure, texture allocation failure, command failure, cancellation, and output encoding failure. User-facing errors preserve a stable code and readable message.

## Testing

### Portable tests

- graph validation accepts a valid source-to-output chain;
- missing dependencies are rejected;
- cycles are rejected deterministically;
- invalid dimensions and values are rejected;
- cache keys are stable for equal requests and change when parameters change;
- cancellation transitions are deterministic;
- preview/export handoff uses identical result bytes.

### Apple-platform tests and CI

- Metal device availability on the macOS/iOS build host;
- shader compilation through the app build;
- deterministic 4x4 and 16x16 fixture rendering;
- inversion, exposure, saturation, opacity, translation, and scale behavior;
- PNG output dimensions and alpha;
- arm64 Release build for iOS 17;
- app identity `After Effects`, version `4.0.0 (4)`;
- unsigned IPA named `After-Effects-4.0.0-unsigned.ipa`.

## Performance evidence

`RenderMetrics` reports CPU encoding time, GPU execution time when available, total elapsed time, input/output pixel counts, and estimated texture bytes. Phase 4 records evidence but does not claim real-time video playback.

## Completion gate

Phase 4 is complete only when:

- portable tests pass;
- Metal shader and backend compile for iOS 17;
- the Render Lab processes a real imported movie thumbnail;
- the displayed preview and exported PNG use the same returned bytes;
- the iOS Release build succeeds;
- the downloaded IPA is inspected as arm64 with version 4.0.0 (4);
- source audit, work log, handoff, workflow, artifact ID, and SHA-256 are recorded.
