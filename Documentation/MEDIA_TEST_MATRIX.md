# Phase 3 Media Test Matrix

## Automated portable tests

The Linux Swift 6.0 CI suite executes 20 tests across `VertexCoreTests` and `VertexMediaTests`.

| Area | Covered behavior |
|---|---|
| Exact time | Normalization, comparison without cross-multiplication overflow, rescaling, signed rounding |
| Identity and metadata | Stable IDs, explicit color descriptors, coordinate conversion |
| Dependency model | Deterministic ordering and cycle failure |
| Milestone policy | Phase 3 identity, source boundaries, GPL isolation, 3.0.0 artifact policy and signing boundary |
| Frame requests | Rejection of invalid target dimensions |
| Waveform values | Paired arrays, finite normalized range, bucket count |
| Cancellation | Token succeeds before cancellation and throws afterward |
| Waveform aggregation | Stereo full-scale, silence, peak and RMS calculation |
| Provider abstraction | Deterministic fake inspector through the public protocol |

## Apple-platform build validation

GitHub Actions uses Xcode 16.4 and the iOS 18.5 SDK while targeting iOS 17.0. The Release build compiles:

- `VertexCore`
- `VertexMedia`
- `VertexMediaAVFoundation`
- the SwiftUI application
- generated app-icon and launch assets

The build gate verifies:

- `CFBundleDisplayName` is `After Effects`;
- bundle identifier is `com.woo642778.aftereffects`;
- version is `3.0.0 (3)`;
- executable is a 64-bit arm64 Mach-O;
- compiled asset catalog exists;
- unsigned IPA packaging succeeds.

## Failure evidence and corrections

The first Phase 3 portable run exposed Phase 2-specific milestone assertions and an older artifact-policy wording contract. Tests were updated to validate Phase 3 rather than deleted.

The first Apple-platform build exposed two platform-specific type issues that Linux could not detect:

- `AVAssetTrack.estimatedDataRate` is `Float` and required an explicit conversion to the portable `Double?` field.
- Core Video color constants bridge as `CFString`; direct switch-pattern casting against `String?` did not compile. The adapter now bridges constants to local `String` values and uses explicit equality checks.

The corrected final source passed both jobs.

## Deferred validation

Phase 3 does not yet include a checked-in media corpus or device-runtime performance benchmark. Phase 4 must add deterministic SDR, HDR, rotated, VFR, silent, audio-only, and damaged fixtures before preview/export parity is claimed. Real-device memory, thermal, and hardware-decoder measurements are also deferred to the render and performance phases.
