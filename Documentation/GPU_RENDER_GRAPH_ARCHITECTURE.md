# GPU Render Graph Architecture

Status: Phase 4

## Purpose

Phase 4 establishes the first production rendering boundary. It converts a portable decoded image into a Metal-rendered PNG through one semantic graph. The same returned PNG bytes drive preview and file export.

## Module boundary

### VertexRender

`VertexRender` is platform-neutral and depends only on `VertexCore` and `VertexMedia`.

It owns:

- `RenderGraph`, `RenderNode`, and `RenderNodeKind`;
- `RenderOperation`;
- `RenderRequest` and `RenderOutputSpecification`;
- `RenderResult`, `RenderMetrics`, and `RenderCacheKey`;
- `RenderBackend`;
- `RenderCancellationToken` and `LatestRenderCoordinator`;
- `RenderError`.

It does not import Metal, MetalKit, Core Image, Core Graphics, ImageIO, UIKit, SwiftUI, AVFoundation, MetalPetal, or VideoIO.

### VertexRenderMetal

`VertexRenderMetal` is the Apple-platform backend. It owns Metal device and queue lifetime, shader compilation, texture allocation, GPU execution, readback, PNG encoding, and timing evidence.

No Metal object is stored in the project-neutral graph or returned to the application.

## Graph form in Phase 4

The supported vertical slice is:

```text
Portable image source
→ ordered Phase 4 operations
→ one output
```

The graph uses stable `VertexID` values and validates all dependencies before backend execution. Exactly one source and exactly one output are required. Missing dependencies, duplicate node IDs, invalid node arity, invalid numeric values, and cycles fail before a GPU command buffer is created.

## Phase 4 operations

The Metal backend supports:

1. normalized translation and uniform scale;
2. exposure in stops;
3. saturation;
4. RGB inversion;
5. opacity over transparent black;
6. output resize.

The application emits these operations in this standard order. Phase 4 executes them in one kernel for one source image. Later effect-stack and node phases may introduce multiple passes while preserving the same `RenderBackend` contract.

## Exact time and color

`RenderRequest.time` is `RationalTime`; no `Double` seconds are stored in the graph.

`RenderOutputSpecification.color` is an explicit `ColorDescriptor`. Phase 4 output defaults to Rec.709/sRGB-compatible SDR with straight alpha. The current shader performs its simple creative operations on normalized RGBA values. Scene-linear processing, HDR transfer handling, wide-gamut transforms, tone mapping, and OCIO/ACES integration remain Phase 22 work.

## Metal execution

The bundled `VertexRenderKernels.metal` source is compiled by Metal at backend initialization. CI separately invokes `xcrun metal` so shader syntax failures are detected before packaging.

For each request the backend:

1. decodes PNG/JPEG bytes through ImageIO;
2. normalizes the source to premultiplied RGBA8;
3. allocates shared input and output textures;
4. uploads source bytes;
5. encodes one compute dispatch;
6. waits for command completion;
7. reads output bytes;
8. encodes a PNG with explicit color-space metadata;
9. returns portable bytes and metrics.

The Phase 4 implementation does not expose a CPU effect fallback. A device without Metal reports `RenderError.metalUnavailable`.

## Preview and export parity

The application displays `RenderResult.image.data` using `UIImage`. `RenderExportDocument` writes the same `Data` value. There is no second export graph, second shader path, or second effect implementation.

The parity contract is therefore byte-identical for this PNG vertical slice, stronger than a pixel-tolerance comparison.

## Scheduling

`LatestRenderCoordinator` implements latest-request-wins behavior:

- a new request cancels the previous token;
- an older result is rejected if it finishes after a newer generation;
- UI slider updates are debounced for 120 milliseconds;
- explicit refresh bypasses the debounce;
- stale results cannot overwrite the latest preview.

## Cache identity

`RenderRequest.cacheKey` uses canonical sorted-key JSON and a portable SHA-256 implementation. The key includes graph IDs, source bytes, operations, exact time, output dimensions, and color metadata.

The cache key is evidence for future cache work; Phase 4 does not yet persist rendered results.

## Metrics

Each result reports:

- CPU decode, command encoding, readback, and PNG-encoding time;
- GPU execution time when reported by the command buffer;
- total elapsed time;
- input and output pixel counts;
- estimated input/output texture bytes.

These values are diagnostic evidence, not a real-time playback claim.

## Resource and safety limits

- output dimensions: 1 to 8192 pixels per dimension;
- saturation execution clamp: 0 to 4;
- opacity execution clamp: 0 to 1;
- scale must be finite and positive;
- all other numeric parameters must be finite;
- source image data must be non-empty and ImageIO-decodable;
- cancellation is checked before submission and after GPU completion.

## Deferred scope

Phase 4 does not implement continuous video playback, temporal effects, multilayer composition, video export, render caching, masks, motion blur, HDR grading, shape rasterization, text, tracking, AI, particles, node editing, or 3D.
