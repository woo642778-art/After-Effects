# Source Adoption Matrix

Status: Phase 1 baseline. Every dependency must be pinned to a reviewed revision before product integration.

| Source | License | Planned mode | Intended contribution | Phase 1 decision |
|---|---|---|---|---|
| `MetalPetal/MetalPetal` | MIT | Direct dependency behind `VertexRenderBackend` | Metal image graph, filters, blending, custom kernels, render optimization | Adopt for Phase 4 spike |
| `MetalPetal/VideoIO` | MIT | Wrapped dependency | AVFoundation composition handler, player frame output, export utilities | Adopt for Phase 3-4 spike |
| `ruanjx/VideoLab` | MIT | Design reference, selective port only after file-level review | Layer, animation, operation, and pre-compose concepts | Study; do not make core dependency |
| `VideoFlint/Cabbage` | MIT | Design reference | AVFoundation timeline and resource abstraction | Study; modernity and concurrency audit required |
| `fwcd/mini-cut` | GPL-3.0 | Behavioral/UI reference only | Timeline gestures, selection, trim and inspector interaction research | No source or assets copied into MIT product |
| `AcademySoftwareFoundation/OpenTimelineIO` | Apache-2.0 | Wrapped interchange dependency | Professional timeline interchange | Defer integration until Phase 27 |
| OpenCV | Apache-2.0 | Wrapped dependency or isolated module | Tracking, geometry, image analysis | Evaluate in Phase 12 |
| ONNX Runtime / Core ML | MIT / Apple platform terms | Wrapped inference backend | Segmentation, depth, tracking, AI automation | Evaluate model-by-model in Phases 13 and 25 |
| OpenColorIO | BSD-3-Clause | Isolated color module | Professional color transforms and interchange | Evaluate mobile viability in Phase 22 |
| FFmpeg | LGPL/GPL depending configuration | Optional isolated codec service | Unsupported formats, analysis, transcoding | Configuration and distribution audit required |

## Verified Phase 1 facts

- MetalPetal declares an MIT license and exposes Metal-based image processing, custom filters, multilayer compositing, color-space handling, and render-graph optimization.
- VideoIO declares an MIT license and exposes AVFoundation composition, player frame output, and configurable export utilities.
- VideoLab declares an MIT-style license and documents layers, keyframes, custom operations, and After Effects-like pre-composition. Its own roadmap lists layer speed adjustment as unfinished, so it is not accepted as the Vertex time engine.

## Adoption process

Before integration, add a source record containing:

1. exact commit SHA or release tag;
2. license text and attribution requirements;
3. build result on the current supported Xcode version;
4. API surface used by Vertex;
5. adapter boundary and removal strategy;
6. known performance and correctness limitations;
7. security and maintenance assessment;
8. reference tests proving preview/export behavior.
