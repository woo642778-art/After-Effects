# Phase 3 Media Input/Output Design

## Goal

Build the first real editor-facing vertical slice: select a local movie, inspect exact media metadata, decode a requested thumbnail, and derive a compact audio waveform while preserving strict boundaries between platform-neutral media contracts and AVFoundation.

## Version and artifact policy

- Phase 3 product version is `3.0.0`.
- Build number is `3`.
- IPA filename is `After-Effects-3.0.0-unsigned.ipa`.
- Every later phase uses its phase number as the major version.

## Architecture

`VertexMedia` is a platform-neutral Swift package target that owns immutable descriptors, requests, provider protocols, cancellation, back-pressure policy, and media errors. It may depend on `VertexCore`, but must not import AVFoundation, UIKit, SwiftUI, MetalPetal, VideoIO, or FFmpeg.

`VertexMediaAVFoundation` is an iOS/macOS adapter target. It translates `AVURLAsset`, `AVAssetTrack`, `AVAssetImageGenerator`, and `AVAssetReader` results into Vertex-owned values. No AVFoundation type may escape its public API.

The application presents a real Files importer. After selection it runs inspection, displays container/stream metadata, requests a representative thumbnail, and computes a normalized audio waveform. Requests are cancellable and stale results are discarded.

## Platform-neutral contracts

- `MediaAssetDescriptor`: stable ID, filename, duration, container hint, video streams, audio streams, metadata flags.
- `VideoStreamDescriptor`: dimensions, nominal frame rate, estimated VFR status, transform, codec, color descriptor, HDR flag, alpha flag.
- `AudioStreamDescriptor`: sample rate, channel count, codec, estimated bitrate.
- `VideoFrameRequest`: exact `RationalTime`, target pixel size, tolerance policy.
- `VideoFrame`: exact requested and actual time plus portable encoded image bytes.
- `AudioWaveformRequest`: exact time range and target bucket count.
- `AudioWaveform`: normalized peak and RMS values.
- `VideoFrameProvider`, `AudioWaveformProvider`, `MediaAssetInspecting` protocols.
- `MediaCancellationToken` and `MediaBackPressurePolicy`.
- `MediaError`: unsupported asset, missing stream, invalid request, cancelled, decode failure, permission failure, and I/O failure.

## AVFoundation implementation

- Load duration, tracks, format descriptions, natural size, preferred transform, nominal frame rate, and color/HDR metadata asynchronously.
- Detect probable VFR conservatively by comparing nominal frame rate with minimum frame duration and sample timing where available. Report `unknown` rather than inventing certainty.
- Generate thumbnails with `AVAssetImageGenerator`, applying preferred transform and exact requested tolerance.
- Generate waveform data with `AVAssetReaderTrackOutput` in linear PCM, aggregating peak and RMS into a bounded number of buckets.
- Treat cancellation as a first-class result and cancel underlying generators/readers.

## App behavior

- Replace the Phase 2 architecture-only root content with a Phase 3 status plus a `Select Media` action.
- Use `fileImporter` for movie files. The selected security-scoped URL is accessed only for the duration of analysis.
- Show loading, failure, and loaded states.
- Loaded state shows thumbnail, duration, dimensions, frame-rate/VFR status, codec, color/HDR status, audio sample rate/channels, and waveform.
- The existing startup, `Made by Maze`, supplied icon, and one-time Telegram promotion remain unchanged.

## Source adoption decisions

- AVFoundation is the production Phase 3 backend.
- VideoIO remains an isolated candidate for Phase 4 preview/export and is not imported in Phase 3 product code.
- MetalPetal is deferred to Phase 4.
- FFmpeg is deferred until a measured unsupported-format requirement and licensing configuration are documented.

## Error and lifecycle rules

- Empty or unsupported assets produce explicit `MediaError` values.
- A new selection cancels the previous task.
- UI state changes occur on the main actor.
- Provider implementations are `Sendable` where correct and isolate mutable AVFoundation objects inside actors.
- No decoded pixel buffers or AVFoundation objects are stored in project-neutral descriptors.

## Testing

- Linux-compatible tests cover descriptor validation, exact request validation, waveform normalization, cancellation, error mapping, and fake-provider behavior.
- macOS/iOS CI compiles the AVFoundation adapter and app.
- A deterministic generated fixture is created in CI for adapter integration tests when practical.
- The unsigned IPA is inspected for arm64, display name, bundle ID, and version `3.0.0 (3)`.

## Non-goals

Phase 3 does not implement a timeline, multi-layer composition, Metal rendering, playback, export, filters, motion, retiming, tracking, AI cutout, shapes, text animation, color grading, audio effects, or 3D.
