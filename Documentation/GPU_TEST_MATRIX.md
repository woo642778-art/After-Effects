# Phase 4 GPU Test Matrix

## Final verified source

- Product and CI HEAD: `2bcc43869cb495feef0297dad3eed59d8548efa7`
- GitHub Actions run: `31060781516`
- Portable test job: 30 tests passed
- Native Metal fixture job: 2 tests passed
- iOS target: iOS 17.0, arm64 Release

## Portable test coverage

| Area | Verified behavior |
|---|---|
| Exact time | Normalization, comparison at integer limits, rescaling, signed rounding |
| Identity | Canonical UUID parsing and stable entity IDs |
| Geometry and color | Coordinate round trip and explicit primaries, transfer, matrix, alpha |
| Dependency graph | Deterministic topological order and cycle reporting |
| Product state | Phase 4 active milestone, 4.0.0 artifact policy, source boundaries |
| Media contracts | Request validation, cancellation, fake providers, waveform validation |
| Audio waveform | Peak/RMS aggregation and codec-padding assignment |
| Render graph | Valid source-operation-output chain, missing node rejection, cycle rejection |
| Render values | Output limits and finite transform/effect parameter validation |
| Cache identity | Stable 64-character SHA-256 key and parameter sensitivity |
| Render scheduling | Cancellation and latest-request-wins stale-result rejection |
| Preview/export parity | Exact equality of preview and exported PNG byte payload |

## Native Metal fixture coverage

The macOS runner uses a real Metal device and executes the Phase 4 compute kernel.

| Fixture | Verification |
|---|---|
| Inverted red source | Interior output pixel becomes cyan with opaque alpha |
| 50% opacity source | Interior output alpha falls within the expected quantized range |
| Output resize | 2×2 PNG source produces a 4×4 PNG result |
| Metrics | Output pixel count matches the requested dimensions |

The first native fixture revision inspected an edge pixel. Linear sampling with `clamp_to_zero` correctly blended transparent border values, causing a false test failure. The test was corrected to inspect an interior pixel rather than weakening the shader.

## Shader and package verification

- `xcrun metal` compiles `VertexRenderKernels.metal` independently.
- SwiftPM compiles the shader into `Vertex_VertexRenderMetal.bundle/default.metallib` for the iOS app.
- `MetalRenderResources` loads `default.metallib` in packaged builds and retains source-compilation fallback for environments where SwiftPM copies the source resource.
- Final IPA contains a 6,996-byte `default.metallib`.

## iOS Release build verification

The final workflow verifies:

- `CFBundleDisplayName`: `After Effects`
- `CFBundleName`: `AfterEffects`
- `CFBundleIdentifier`: `com.woo642778.aftereffects`
- `CFBundleShortVersionString`: `4.0.0`
- `CFBundleVersion`: `4`
- `MinimumOSVersion`: `17.0`
- executable: Mach-O 64-bit arm64
- compiled `Assets.car`
- compiled `Vertex_VertexRenderMetal.bundle/default.metallib`
- unsigned IPA packaging and checksum generation

## Final artifact

- Artifact ID: `8952047400`
- Artifact name: `After-Effects-4.0.0-unsigned-ipa`
- Artifact archive SHA-256: `ce8f6fe16ca4bfe3f07b2ddd4d5b9fb0c6322dac1605a025f7657b8c53ef78a8`
- Extracted IPA SHA-256: `fb4aac8c8370dc90f3b347cb7fbb2548d05808d1d2a5a091b868a41a420be331`

## Known limits

Phase 4 does not verify continuous video playback, audio/video synchronization, multilayer composition, video-file export, temporal effects, HDR grading accuracy, render cache persistence, real-device thermal behavior, or large-project memory pressure. These are gated to later phases.
