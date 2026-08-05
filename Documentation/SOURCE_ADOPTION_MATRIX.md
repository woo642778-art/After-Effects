# Source Adoption Matrix

Status: Phase 3. Every third-party dependency must be pinned to a reviewed revision before product integration. Apple platform frameworks are still isolated behind Vertex-owned adapters.

| Source | License | Mode | Intended contribution | Current decision |
|---|---|---|---|---|
| Apple AVFoundation | Apple platform SDK | Wrapped platform dependency | Asset inspection, native decode, frame generation, PCM extraction | Adopted in Phase 3 behind `VertexMediaAVFoundation`; no platform types escape |
| `MetalPetal/MetalPetal` | MIT | Direct dependency behind future `VertexRenderBackend` | Metal image graph, filters, blending, custom kernels, render optimization | Phase 4 audit and spike required before integration |
| `MetalPetal/VideoIO` | MIT | Wrapped dependency candidate | AVFoundation player output, composition, export utilities | Deferred from Phase 3; Phase 4 isolated evaluation only |
| `ruanjx/VideoLab` | MIT | Design reference, selective port only after file-level review | Layer, animation, operation, and pre-compose concepts | Study; never use as core time, media, or project engine |
| `VideoFlint/Cabbage` | MIT | Design reference | AVFoundation timeline and resource abstraction | Study; modernity and concurrency audit required |
| `fwcd/mini-cut` | GPL-3.0 | Behavioral/UI reference only | Timeline gestures, selection, trim, and inspector interaction research | No source or assets copied into the MIT-oriented product |
| `AcademySoftwareFoundation/OpenTimelineIO` | Apache-2.0 | Wrapped interchange dependency candidate | Professional timeline interchange | Defer integration until Phase 27 |
| OpenCV | Apache-2.0 | Wrapped dependency or isolated module candidate | Tracking, geometry, image analysis | Evaluate in Phase 12 |
| ONNX Runtime / Core ML | MIT / Apple platform terms | Wrapped inference backend candidate | Segmentation, depth, tracking, AI automation | Evaluate model-by-model in Phases 13 and 25 |
| OpenColorIO | BSD-3-Clause | Isolated color module candidate | Professional color transforms and interchange | Evaluate mobile viability in Phase 22 |
| FFmpeg | LGPL/GPL depending configuration | Optional isolated codec service | Unsupported formats, analysis, transcoding | Not integrated in Phase 3; require measured need and distribution audit |

## Verified decisions

- Phase 3 uses AVFoundation for real metadata, thumbnail, and waveform behavior while retaining platform-neutral `VertexMedia` contracts.
- MetalPetal declares an MIT license and is the leading Phase 4 GPU-processing candidate, but no Phase 3 product code imports it.
- VideoIO declares an MIT license and remains a Phase 4 preview/export candidate, not a Phase 3 dependency.
- VideoLab documents layers, keyframes, operations, and pre-composition. Its unfinished speed work and small scope prevent adoption as the Vertex time engine.
- MiniCut remains GPL-3.0 behavioral reference only.
- FFmpeg was deliberately deferred because broader format support has not yet justified app size, license configuration, hardware-decoder integration, and distribution complexity.

## Adoption process

Before third-party product integration, add a source record containing:

1. exact commit SHA or release tag;
2. license text and attribution requirements;
3. build result on the supported Xcode and deployment target;
4. exact API surface used by Vertex;
5. adapter boundary and removal strategy;
6. known performance and correctness limitations;
7. security and maintenance assessment;
8. deterministic reference tests;
9. preview/export parity evidence when the source participates in rendering;
10. binary-size and energy impact where relevant.
