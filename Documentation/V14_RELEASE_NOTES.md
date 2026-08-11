# Vertex2 14.0.0

Phase 14 adds tracking, stabilization, and rotoscoping to the iPad editing workflow.

## What’s new

- Point, planar, and object motion tracking.
- Face and body subject initialization where supported by Apple Vision.
- Deterministic exact-rational frame sampling.
- Correct source-frame decoding for layer start time, source trim, source offset, and time-remapped layers.
- Follow and stabilization transforms applied through real animation channels.
- Camera-motion analysis summaries.
- Tracked mask / rotoscope propagation with playhead refinements.
- Export-safe animated Bezier mask paths.
- Tracking & Rotoscope controls integrated into Automation.
- Regression coverage for tracking solve, source-time mapping, animation application, and rotoscope propagation.

## Build

- Version: 14.0.0
- Build: 14
- Bundle ID: `com.woo642778.aftereffects`
- Platform: iPad only, iOS 17+
- Distribution: unsigned IPA; installation requires signing/re-signing.
