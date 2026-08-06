# Source Adoption Matrix

Status: Phase 4. Every third-party dependency must be pinned to a reviewed revision before product integration. Apple platform frameworks remain isolated behind Vertex-owned adapters.

| Source | License | Mode | Intended contribution | Current decision |
|---|---|---|---|---|
| Apple AVFoundation | Apple platform SDK | Wrapped platform dependency | Asset inspection, native decode, frame generation, PCM extraction | Adopted in Phase 3 behind `VertexMediaAVFoundation`; no platform types escape |
| Apple Metal | Apple platform SDK | Wrapped platform dependency | GPU texture processing and compute execution | Adopted in Phase 4 behind `VertexRenderMetal`; no Metal types escape |
| Apple Core Graphics / ImageIO | Apple platform SDK | Wrapped platform dependency | Portable image decode, normalized RGBA conversion, PNG encode | Adopted inside `VertexRenderMetal` only |
| `MetalPetal/MetalPetal` | MIT | Future backend/effect adapter candidate | Filters, blending, multilayer compositing, custom kernels, render optimization | Audited at `f9b78897bd4214bb097f352a1bde0a4f4a1e2ddb`; not linked in Phase 4 |
| `MetalPetal/VideoIO` | MIT | Future wrapped dependency candidate | Player output, composition, recording, export utilities | Audited at `1623b3d597d8ae987979ce8ac7b1ce0d085d2855`; deferred until timed preview/export |
| `ruanjx/VideoLab` | MIT | Design reference, selective port only after file-level review | Layer, animation, operation, and pre-compose concepts | Study; never use as core time, media, project, or Phase 4 graph engine |
| `VideoFlint/Cabbage` | MIT | Design reference | AVFoundation timeline and resource abstraction | Study; modernity and concurrency audit required |
| `fwcd/mini-cut` | GPL-3.0 | Behavioral/UI reference only | Timeline gestures, selection, trim and inspector interaction research | No source or assets copied into the MIT-oriented product |
| `AcademySoftwareFoundation/OpenTimelineIO` | Apache-2.0 | Wrapped interchange dependency candidate | Professional timeline interchange | Defer integration until Phase 27 |
| OpenCV | Apache-2.0 | Wrapped dependency or isolated module candidate | Tracking, geometry, image analysis | Evaluate in Phase 12 |
| ONNX Runtime / Core ML | MIT / Apple platform terms | Wrapped inference backend candidate | Segmentation, depth, tracking, AI automation | Evaluate model-by-model in Phases 13 and 25 |
| OpenColorIO | BSD-3-Clause | Isolated color module candidate | Professional color transforms and interchange | Evaluate mobile viability in Phase 22 |
| FFmpeg | LGPL/GPL depending configuration | Optional isolated codec service | Unsupported formats, analysis, transcoding | Not integrated; require measured need and distribution audit |

## Verified decisions

- Phase 3 uses AVFoundation for real metadata, thumbnail, and waveform behavior while retaining platform-neutral `VertexMedia` contracts.
- Phase 4 uses a native Metal compute backend while retaining platform-neutral `VertexRender` contracts.
- Preview and PNG export consume the same portable `RenderResult.image.data` bytes.
- MetalPetal remains a leading future effect and composition candidate, but it is not allowed to define project-neutral graph, time, color, or result types.
- VideoIO remains a future continuous-preview and video-export candidate; Phase 4 has no timed output requirement.
- VideoLab remains a layer/pre-composition design reference rather than a time, media, project, or render foundation.
- MiniCut remains GPL-3.0 behavioral reference only.
- FFmpeg remains deferred because broader format support has not yet justified app size, license configuration, hardware-decoder integration, and distribution complexity.

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
