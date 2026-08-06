# Phase 4 GPU Source Audit

Audit date: 2026-08-05

## Decision summary

Phase 4 uses Apple Metal, Core Graphics, and ImageIO directly behind `VertexRenderMetal`. MetalPetal and VideoIO remain approved future candidates but are not linked into the 4.0.0 product.

This decision is not a rejection of their code quality. It prevents an external API from becoming the project model before Vertex owns stable time, color, graph, cancellation, result, and parity contracts.

## MetalPetal

- Repository: `MetalPetal/MetalPetal`
- License: MIT
- Reviewed connector revision: `f9b78897bd4214bb097f352a1bde0a4f4a1e2ddb`
- Intended future role: GPU filter kernels, blend modes, multilayer compositing, render-graph optimization, and custom filter support behind `RenderBackend` or narrower effect adapters.
- Phase 4 product linkage: none.

### Useful design evidence

MetalPetal demonstrates mature separation between image descriptions, kernels, render context, and output. Its effect catalog and texture-management work remain important references for Phase 17 and later performance phases.

### Why it is not the Phase 4 foundation

- Vertex first needs its own exact-time and color contracts.
- Preview/export semantics must be proven independently of one backend.
- The initial vertical slice requires only one source and one kernel.
- Early direct linkage would make removal and backend comparison harder.

### Re-evaluation gate

Before adoption, pin a release or commit, build it with the active Xcode and iOS floor, measure binary size and render latency against the native backend, define the exact adapter surface, and run identical SDR/HDR/alpha fixtures.

## VideoIO

- Repository: `MetalPetal/VideoIO`
- License: MIT
- Reviewed connector revision: `1623b3d597d8ae987979ce8ac7b1ce0d085d2855`
- Intended future role: player frame output, custom video composition, recording, and configurable export utilities.
- Phase 4 product linkage: none.

### Why it is deferred

Phase 3 already wraps AVFoundation decoding in `VertexMediaAVFoundation`. Phase 4 exports a still PNG, not a timed video asset. Integrating VideoIO now would overlap existing responsibilities without proving continuous playback or video export.

### Re-evaluation gate

Evaluate VideoIO when Phase 6/9/26 work needs continuous preview, custom `AVVideoCompositing`, pause/resume export, or recording. The evaluation must prove that one Vertex semantic graph drives both player frames and file output.

## VideoLab and other references

VideoLab remains a design reference for later layer, operation, animation, and pre-composition work. It is not used as the render graph, time engine, or media backend.

MiniCut remains GPL-3.0 behavioral reference only. No UI source or assets were copied into Phase 4.

## Code provenance for Phase 4

The Phase 4 product implementation is original project code using public Apple SDK APIs. No MetalPetal, VideoIO, VideoLab, MiniCut, Sapphire, BCC, After Effects, Alight Motion, Node Video, or Blurrr code, shaders, presets, names, or assets were copied into the render backend.
