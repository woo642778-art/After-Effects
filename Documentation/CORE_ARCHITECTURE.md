# Core Architecture

Phase 2 establishes the platform-neutral contracts that every later media, timeline, render, motion, effect, tracking, AI, shape, text, audio, color, and 3D subsystem must use. These types live in `VertexCore`. The installed product is named After Effects, while the internal `Vertex` namespace remains the engine architecture name so the repository can distinguish product identity from low-level modules.

## Exact time

`RationalTime` stores an integer value and a positive integer timescale. Equivalent fractions normalize to one representation, comparisons use wide integer arithmetic, addition and subtraction report overflow, and rescaling requires an explicit rounding mode. Project and timeline data must not persist `Double` seconds. AVFoundation conversion will occur only at the media adapter boundary in a later phase.

The current representation deliberately limits the normalized timescale to `Int32.max`. A future media adapter must reject or deliberately rescale values that exceed this domain instead of silently truncating them.

## Stable identity

`VertexID` is a canonical lower-case UUID string. Project entities will keep the same identifier across saves, migrations, undo history, relinking, render-cache keys, and collaboration records. Display names, array positions, file paths, and object memory addresses are never valid entity identities.

## Coordinate spaces

`VertexCoordinateSpace` names four initial spaces: top-left pixels, center-relative pixels, top-left normalized coordinates, and center-relative normalized coordinates. `CoordinateConverter` requires a valid canvas size and always names both the source and destination spaces. Future 3D, camera, mask, text, shape, tracking, and screen-coordinate systems must add explicit conversion boundaries instead of reusing ambiguous points.

## Color metadata

`ColorDescriptor` carries primaries, transfer function, matrix, and alpha mode as independent fields. The initial catalog includes Rec.709 SDR, Display P3 SDR, and Rec.2020 PQ descriptors. It does not perform color conversion yet. Later media and render phases must preserve this descriptor with each frame and perform conversions through a dedicated color-management layer.

## Dependency evaluation

`DependencyGraph` preserves insertion order, emits dependencies before dependents, ignores duplicate edges, and throws `DependencyCycle` with a stable path when a cycle is found. Render graphs, pre-compositions, node graphs, expression links, effect dependencies, masks, tracking data, and project migrations must use explicit dependency evaluation rather than recursive object calls with hidden ordering.

## Structured errors

`VertexError` contains a subsystem domain, stable machine-readable code, human-readable message, and string diagnostic context. Future subsystems must not expose unclassified `NSError`, opaque strings, or process crashes as their public failure contract. Platform errors may be wrapped at adapter boundaries while preserving the original diagnostic description in context.

## Phase boundary

Phase 2 does not implement media decoding, a production timeline, GPU rendering, export, motion, effects, masks, tracking, AI cutout, shapes, text animation, color conversion, audio processing, or 3D. It provides the contracts those systems must build on and tests their deterministic behavior before product features begin.
