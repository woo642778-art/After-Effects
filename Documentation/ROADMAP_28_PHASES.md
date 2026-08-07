# Vertex 28-Phase Roadmap

Each phase is a gated engineering program. A phase may contain many milestones and pull requests. Later phases may start research early, but production integration cannot bypass prerequisite gates.

For the detailed 7.0.0–26.0.0 scope, implementation order, release naming, and non-negotiable gates, see [`Documentation/ROADMAP_7_TO_26.md`](ROADMAP_7_TO_26.md).

| Phase | Version | Program | Required outcome |
|---:|---|---|---|
| 0 | Foundation | Repository and quality bootstrap | Branching, CI, test, documentation, licensing, and artifact rules |
| 1 | 1.0.0 | Source audit and foundation | Verified adoption matrix, milestone shell, persistent handoff, unsigned IPA pipeline |
| 2 | 2.0.0 | Core architecture | Exact time, coordinate, color, identity, dependency, and error models |
| 3 | 3.0.0 | Media input/output | Video, image, audio, VFR, HDR metadata, frame and sample providers |
| 4 | 4.0.0 | GPU render graph | Metal-backed composition with one preview/export semantic path |
| 5 | 5.0.0 | Project persistence | Canonical `.vertexproject`, crash-safe save/recovery, immutable autosave, bookmark sidecars, session-only Undo/Redo, legacy import |
| 6 | 6.0.0 | Layers and compositions | Media, adjustment, null, guide, camera, light, nested composition model and multi-source rendering |
| 7 | 7.0.0 | Motion engine | Generic animation channels, keyframes, temporal/spatial interpolation, parenting, real temporal motion blur |
| 8 | 8.0.0 | Masks and mattes | Animated Bezier masks, feather/expansion, mask modes, alpha/luma track mattes |
| 9 | 9.0.0 | Professional NLE timeline | Multitrack timeline, playback, trim/split, ripple/roll/slip/slide, snapping, multiselect |
| 10 | 10.0.0 | Time engine and retiming | Speed changes, reverse, freeze, time maps, ramps, frame blending, optical-flow boundary |
| 11 | 11.0.0 | Professional color, HDR, and scopes | Managed color pipelines, Log/HDR transforms, grading tools, LUT/CDL, scopes, tone mapping |
| 12 | 12.0.0 | Audio studio | Sample-accurate multitrack audio, buses, dynamics, restoration, LUFS, beats, stems/captions foundations |
| 13 | 13.0.0 | Text and vector engine | Text shaping/animation, shape layers, paths, fill/stroke, gradients, Trim Paths, Repeater |
| 14 | 14.0.0 | Tracking, stabilization, and rotoscoping | Point/planar/object tracking, mask tracking, stabilization, manual roto and propagation architecture |
| 15 | 15.0.0 | Effects architecture | Typed GPU effect system, reusable kernels, animatable parameters, presets, effect migration/versioning |
| 16 | 16.0.0 | Advanced pre-composition and nesting | Pre-compose workflow, nested timing, collapse-transform style behavior, dependency caching |
| 17 | 17.0.0 | Particles and procedural graphics | Deterministic GPU particles, emitters, forces, turbulence, trails, procedural/noise generators |
| 18 | 18.0.0 | Node compositor | Free node workspace backed by the same render graph and kernels as the layer system |
| 19 | 19.0.0 | AI studio | Cutout/segmentation, depth, AI-assisted tracking/masking, denoise/deblur/interpolation integration boundaries |
| 20 | 20.0.0 | AI upscale and restoration | Super-resolution, restoration, artifact cleanup, tiled inference, model management and benchmarking |
| 21 | 21.0.0 | Asset and preset ecosystem | In-app assets, presets, transitions, LUTs, fonts/audio where licensed, search/favorites/direct insertion |
| 22 | 22.0.0 | 3D foundation | Z transforms, 2.5D, 3D hierarchy, depth ordering, materials and scene foundations |
| 23 | 23.0.0 | 3D scene workspace | 3D viewport, gizmos, scene hierarchy, meshes/materials/textures, GLTF/GLB import |
| 24 | 24.0.0 | Camera, light, and full 3D rendering | Real cameras/lights, shadows, PBR foundation, DOF, environment/depth compositing |
| 25 | 25.0.0 | Expressions, automation, and extensibility | Property linking, deterministic expression sandbox, constraints, macros, automation and extension boundaries |
| 26 | 26.0.0 | Scale, cache, and final export architecture | Proxy/cache/resource pools, background render, render queue, long-project stability, production video/HDR export |
| 27 | 27.0.0 | Interchange and release qualification | OTIO/XML/AAF research, compatibility, device/performance/crash qualification, final release gates |

## Release rule

For Phase `N`, the expected product artifact is:

`After-Effects-N.0.0-unsigned.ipa`

A phase is complete only after its implementation, deterministic tests, applicable iOS Simulator coverage, iOS 17+ arm64 Release build, IPA inspection, and SHA-256 verification pass.

## Global gate

No phase may weaken exact time handling, preview/export parity, canonical `.vertexproject` recoverability, source-license traceability, deterministic testing, or established persistence invariants without an explicitly approved architecture change.
