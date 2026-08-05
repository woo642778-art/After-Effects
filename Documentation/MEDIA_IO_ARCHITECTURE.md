# Phase 3 Media Input/Output Architecture

## Purpose

Phase 3 introduces the first real editor-facing media workflow. A user can select a local movie, inspect actual stream metadata, decode a representative frame, and derive an audio waveform. It deliberately does not introduce timeline playback, multilayer composition, rendering, or export.

## Module boundary

```text
VertexCore
   ↑
VertexMedia
   ↑
VertexMediaAVFoundation
   ↑
After Effects SwiftUI application
```

`VertexMedia` is platform-neutral. It owns stable data and protocols only. It imports `VertexCore` for `RationalTime`, `VertexID`, `VertexSize`, and `ColorDescriptor`. It does not import AVFoundation, Core Media, UIKit, SwiftUI, MetalPetal, VideoIO, or FFmpeg.

`VertexMediaAVFoundation` is the platform adapter. `AVURLAsset`, `AVAssetTrack`, `CMTime`, `CMFormatDescription`, `CGImage`, `CMSampleBuffer`, and `AVAssetReader` remain inside this target. Public methods consume and return Vertex-owned values.

## Portable contracts

- `MediaAssetDescriptor` describes a selected asset without retaining the file URL or platform object.
- `VideoStreamDescriptor` stores displayed dimensions after preferred transform, nominal frame rate, conservative VFR classification, codec, color metadata, HDR, alpha, and rotation.
- `AudioStreamDescriptor` stores sample rate, channel count, codec, and optional estimated bitrate.
- `VideoFrameRequest` uses exact `RationalTime`, a bounded target size, and explicit tolerance.
- `PortableImage` stores encoded PNG or JPEG bytes and pixel dimensions.
- `AudioWaveformRequest` contains an exact time range and bounded bucket count.
- `AudioWaveform` stores paired normalized peak and RMS buckets.
- `MediaCancellationToken` provides explicit cancellation shared across application and adapter layers.
- `MediaError` distinguishes unsupported media, missing streams, invalid requests, cancellation, permission, decoding, and I/O failure.

## Metadata inspection

`AVFoundationMediaInspector` asynchronously loads asset duration and audio/video tracks. Video stream mapping includes preferred-transform-aware dimensions, rotation, FourCC codec name, nominal frame rate, minimum frame duration, color primaries, transfer function, YCbCr matrix, HDR classification, and alpha availability. VFR status is conservative: insufficient evidence returns `unknown` rather than a fabricated constant or variable classification.

## Thumbnail decoding

`AVFoundationVideoFrameProvider` applies the asset's preferred transform, bounds output size, supports exact or nearest-frame tolerance, converts the resulting `CGImage` to PNG, and returns both requested and actual exact time. Decode failures and cancellation become `MediaError` values.

## Waveform extraction

`AVFoundationAudioWaveformProvider` uses `AVAssetReaderTrackOutput` configured for interleaved 32-bit floating-point PCM. Samples are clamped to the normalized audio range and aggregated into bounded peak and RMS buckets by `WaveformAccumulator`. The provider checks task and explicit-token cancellation between sample buffers and cancels the reader when necessary.

## Application lifecycle

The SwiftUI app uses the system Files importer for movie types. It does not request Photos access. Security-scoped file access remains active only while inspection, frame decoding, and waveform extraction run. Selecting another file cancels the previous task, and stale results are rejected by selection identity.

The loaded surface presents the real filename, duration, container hint, video dimensions, codec, nominal frame rate, VFR status, color/HDR metadata, audio sample rate and channels, thumbnail, and waveform.

## Invariants

- Timeline and source time remain exact `RationalTime` values.
- No AVFoundation object is serialized or exposed from the adapter.
- Cancellation is not represented as a generic decode failure.
- Unknown metadata remains unknown instead of being guessed.
- Phase 4 preview and export must consume these provider contracts rather than create a second media model.
