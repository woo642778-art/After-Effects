# Phase 3 Media Source Audit

## Production decision

Phase 3 uses Apple AVFoundation as the production media backend behind `VertexMediaAVFoundation`. This is a platform framework rather than copied third-party source. It provides native file coordination, hardware-backed decoding where supported, stream metadata, image generation, and PCM extraction on iOS 17.

## Evaluated candidates

| Candidate | Phase 3 decision | Rationale |
|---|---|---|
| Apple AVFoundation | Adopt behind adapter | Native iOS lifecycle, codec support, security-scoped URL compatibility, hardware decoding, and no additional binary payload |
| MetalPetal/VideoIO | Defer to Phase 4 isolated evaluation | Most relevant to preview/export and MetalPetal integration, not required for metadata, thumbnail, or waveform contracts |
| MetalPetal/MetalPetal | Defer to Phase 4 | GPU render backend and effects foundation, not a general asset-inspection layer |
| FFmpeg | Reject for Phase 3, retain research option | Broader format coverage does not yet justify binary size, license configuration, hardware-decoder integration, and distribution complexity |
| ruanjx/VideoLab | Design reference only | Useful layer and composition concepts but not accepted as the media time or provider foundation |
| VideoFlint/Cabbage | Design reference only | Relevant AVFoundation abstraction ideas, but older code and timeline concerns are outside Phase 3 |
| fwcd/mini-cut | Behavioral reference only | GPL-3.0 timeline UI cannot be copied into the current MIT-oriented product strategy |

## Adoption boundary

AVFoundation types are isolated in `Sources/VertexMediaAVFoundation`. The platform-neutral target is checked by Linux compilation, where the AVFoundation implementation is excluded by `canImport(AVFoundation)` and all portable contracts remain testable.

VideoIO must not be added as a direct app-wide dependency in Phase 4. Any experiment must document an exact revision, license, used APIs, preview/export behavior, removal strategy, and performance measurements before adoption.

FFmpeg remains conditional. A future proposal must identify specific unsupported formats, choose an LGPL-compatible configuration where possible, document dynamic/static linking consequences, and compare energy, latency, app size, hardware acceleration, and App Store distribution requirements.

## Code provenance

Phase 3 production code was implemented for this repository. No source code or assets were copied from VideoIO, MetalPetal, VideoLab, Cabbage, MiniCut, FFmpeg, Alight Motion, Node Video, Blurrr, After Effects, DaVinci Resolve, Sapphire, or Continuum.
