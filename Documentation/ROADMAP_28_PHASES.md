# Vertex 28-Phase Roadmap

Each phase is a gated engineering program. A phase may contain many milestones and pull requests. Later phases may start research early, but production integration cannot bypass prerequisite gates.

| Phase | Program | Required outcome |
|---:|---|---|
| 0 | Repository and quality bootstrap | Branching, CI, test, documentation, licensing, and artifact rules |
| 1 | Source audit and foundation | Verified adoption matrix, milestone shell, persistent handoff, unsigned IPA pipeline |
| 2 | Core architecture | Exact time, coordinate, color, identity, dependency, and error models |
| 3 | Media input/output | Video, image, audio, VFR, HDR metadata, frame and sample providers |
| 4 | GPU render graph | Metal-backed composition with one preview/export semantic path |
| 5 | Project persistence | Versioned schema, undo/redo, journaling, recovery, migration, relinking |
| 6 | Layers and compositions | Media, adjustment, null, guide, camera, light, nested composition model |
| 7 | Motion engine | Generic animation channels, temporal/spatial interpolation, parenting, motion blur |
| 8 | Graphs, expressions, constraints | Value/speed graphs, linking, expressions, drivers, constraints |
| 9 | NLE timeline | Multitrack editing, ripple/roll/slip/slide, source-record workflow |
| 10 | Retiming | Constant speed, reverse, freeze, time maps, velocity curves, frame synthesis |
| 11 | Masks and rotoscoping | Bézier masks, mattes, feathering, manual roto, editable propagation |
| 12 | Tracking and stabilization | Point, planar, object, face/body, camera solve, stabilization |
| 13 | AI cutout and rotobrush | Prompt/brush-guided segmentation, temporal propagation, edge refinement |
| 14 | Shape engine | Advanced vector paths, modifiers, booleans, gradients, morphing, GPU rendering |
| 15 | Text motion engine | Shaping, variable fonts, text animators, selectors, path text, multilingual layout |
| 16 | Pre-composition and nesting | Nested time, collapse transforms, continuous rasterization, dependency caching |
| 17 | Built-in effects program | Broad AE-class effect categories with documented parity and 32-bit/HDR behavior |
| 18 | VertexFX SDK and builder | Typed effect descriptors, custom controls, graph macros, bundled extensions |
| 19 | Professional effects families | Independent Sapphire/BCC-class glow, lens, distortion, repair, stylize, transition tools |
| 20 | Particles and simulation | Deterministic GPU particles, fields, trails, collision, procedural environments |
| 21 | Node compositing | Layer stack and free graph backed by the same render graph and effect kernels |
| 22 | Color, HDR, and scopes | Scene/display pipelines, OCIO/ACES research, grading nodes, scopes, tone mapping |
| 23 | Audio studio | Sample-accurate editing, buses, automation, dynamics, restoration, loudness |
| 24 | 2.5D and professional 3D | Cameras, lights, PBR, models, extrusion, passes, depth integration, tracked scenes |
| 25 | Advanced AI automation | Depth, inpainting, interpolation, transcription, reframing, analysis, assisted editing |
| 26 | Performance, cache, export | Proxy, render cache, texture pool, long-project stability, background rendering |
| 27 | Interchange, SDK, validation | OTIO/XML/AAF research, plugin packaging, regression suites, release qualification |

## Global gate

No phase may weaken exact time handling, preview/export parity, project recoverability, source-license traceability, or deterministic testing.
