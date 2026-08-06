# Phase 4 Completion Record

## Scope

Phase 4 adds the first GPU rendering vertical slice. A movie selected through the Phase 3 importer supplies a decoded thumbnail. A platform-neutral graph describes processing, a native Metal backend executes it, and the returned PNG bytes are used for both preview and file export.

## Implemented

### VertexRender

- portable render graph, nodes, operations, requests, results, metrics, and errors
- exact `RationalTime` requests and explicit `ColorDescriptor` output
- unique-ID, dependency, node-arity, value, and cycle validation
- deterministic sorted-JSON SHA-256 cache keys
- cancellation and latest-request-wins scheduling
- exact-byte preview/export parity contract
- no Apple rendering framework or third-party rendering type in the public model

### VertexRenderMetal

- ImageIO PNG/JPEG decoding and PNG encoding
- premultiplied RGBA8 normalization
- Metal device, queue, pipeline, texture, command, and readback handling
- translation, scale, exposure, saturation, inversion, opacity, and resizing
- CPU, GPU, total-time, pixel-count, and texture-memory metrics
- packaged `default.metallib` loading with source fallback for test environments

### Application Render Lab

- real imported-thumbnail GPU preview
- exposure, saturation, opacity, inversion, scale, and X/Y translation controls
- 720, 1080, 1440, and 2160 long-edge output choices
- 120 ms debouncing and stale-result rejection
- timing and cache-key presentation
- PNG export that writes the exact bytes shown in preview

## Source decisions

- Apple Metal is used behind `VertexRenderMetal`.
- MetalPetal was reviewed at `f9b78897bd4214bb097f352a1bde0a4f4a1e2ddb`; it remains an unlinked future effect/composition candidate.
- VideoIO was reviewed at `1623b3d597d8ae987979ce8ac7b1ce0d085d2855`; it remains deferred until timed preview or video export.
- VideoLab remains a design reference.
- MiniCut remains GPL behavioral reference only.
- No external editor UI, shader, proprietary effect, preset, or asset was copied into Phase 4.

## Debugging record

1. The first Metal fixture inspected a border pixel. Linear sampling correctly blended the transparent boundary, so the test was changed to inspect an interior pixel rather than changing the shader.
2. The iOS build compiled the shader source into `Vertex_VertexRenderMetal.bundle/default.metallib`. The runtime loader and CI verification were corrected to use the compiled library.
3. The 4.0.0 app initially retained Phase 3 milestone text in two regression locations. The milestone catalog, artifact policy, source modes, and both tests were updated to Phase 4.

## Final verification

- Product and CI HEAD: `2bcc43869cb495feef0297dad3eed59d8548efa7`
- Workflow run: `31060781516`
- Portable tests: 30 passed
- Native Metal tests: 2 passed
- Metal source compilation: passed
- XcodeGen generation: passed
- iOS 17 arm64 Release build: passed
- Identity, version, asset, and Metal-library checks: passed
- IPA packaging and upload: passed

## Artifact

- Artifact ID: `8952047400`
- Artifact name: `After-Effects-4.0.0-unsigned-ipa`
- Archive SHA-256: `ce8f6fe16ca4bfe3f07b2ddd4d5b9fb0c6322dac1605a025f7657b8c53ef78a8`
- IPA SHA-256: `fb4aac8c8370dc90f3b347cb7fbb2548d05808d1d2a5a091b868a41a420be331`

Downloaded IPA inspection:

- `Payload/AfterEffects.app/AfterEffects`: Mach-O 64-bit arm64
- display name: `After Effects`
- bundle identifier: `com.woo642778.aftereffects`
- version: `4.0.0 (4)`
- minimum OS: iOS 17.0
- `Assets.car`: present
- `Vertex_VertexRenderMetal.bundle/default.metallib`: present, 6,996 bytes

## Current product boundary

Implemented: media selection and inspection, thumbnail and waveform analysis, native Metal still-frame processing, Render Lab controls, metrics, and exact-preview PNG export.

Not implemented: continuous playback, timeline editing, multilayer composition, video export, project persistence, general effects, keyframes, retiming, masks, tracking, AI cutout, shapes, text animation, professional color/audio, particles, nodes, or 3D.

## Phase 5 start gate

Phase 5 is project persistence. It must define a versioned schema, atomic save and journal behavior, undo/redo commands, crash recovery, autosave snapshots, migrations, media relinking, deterministic serialization, and corruption fixtures before version `5.0.0 (5)` is published.
