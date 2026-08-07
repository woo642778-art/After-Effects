# AI Upscale & Video Restoration Roadmap

## 1. Goal

Add a production-grade AI upscaling system to After-Effects for iOS. The feature must do more than resize pixels: it should restore useful detail, reduce compression artifacts and noise, preserve temporal consistency in video, and integrate with the existing preview/export pipeline without blocking normal editing.

The long-term target is a hybrid architecture:

- **On-device mode** for offline, private, low-cost enhancement using Core ML / Metal.
- **Professional cloud mode** for optional high-quality processing through a licensed external provider such as the Topaz Labs API.
- **Preview acceleration** using Metal/MetalFX where appropriate. MetalFX is a rendering upscaler and must not be treated as a replacement for restoration-oriented AI super-resolution.

Topaz proprietary models must never be copied, extracted, bundled, reverse-engineered, or redistributed. Topaz integration, if enabled, must use an officially licensed API or another explicit commercial agreement.

---

## 2. Product Experience

### Entry points

AI Upscale should be available from:

1. Clip inspector / video properties.
2. Export settings.
3. A dedicated `AI Enhance` panel for advanced controls.

### Primary controls

- `Auto Enhance`
- `Upscale`: Off / 2x / 4x / 1080p / 1440p / 4K
- `Model`: Auto / Fast / Standard / Detail / Anime / Professional Cloud
- `Recover Detail`
- `Reduce Noise`
- `Remove Compression`
- `Sharpen`
- `Face Recovery`
- `Temporal Consistency`
- `Preview Region`
- Before / After split preview

The default workflow should remain simple. `Auto Enhance` analyzes the source and chooses safe parameters, while manual controls remain available for advanced users.

---

## 3. High-Level Architecture

```text
Asset / Timeline Frame
        |
        v
Source Analyzer
(resolution, noise, blur, compression, face/content type)
        |
        v
Enhancement Planner
        |
        +---------------------------+
        |                           |
        v                           v
On-Device Engine              Professional Cloud
Core ML + Metal               Licensed Topaz API
        |                           |
        +-------------+-------------+
                      |
                      v
Temporal / Artifact Validation
                      |
                      v
Color Management
                      |
                      v
Preview Cache or Export Encoder
```

### Proposed module boundaries

```text
Sources/
  VertexAIUpscale/
    AIUpscaleConfiguration.swift
    AIUpscaleEngine.swift
    AIUpscaleModelRegistry.swift
    AIUpscaleSourceAnalyzer.swift
    AIUpscalePlanner.swift
    AIUpscaleTileProcessor.swift
    AIUpscaleFrameProcessor.swift
    AIUpscaleTemporalCoordinator.swift
    AIUpscaleCache.swift
    AIUpscaleMetrics.swift
    CoreML/
      CoreMLSuperResolutionBackend.swift
      CoreMLModelLoader.swift
    Metal/
      MetalTileCompositor.swift
      MetalTextureConverter.swift
      MetalUpscaleKernels.metal
    Cloud/
      CloudUpscaleProvider.swift
      TopazUpscaleProvider.swift
      CloudUpscaleJob.swift
```

Names may be adapted to the repository's actual module conventions when implementation begins.

---

## 4. Phase 1: On-Device MVP

### Objective

Ship a reliable offline 2x AI upscale path first. Do not begin with full Topaz-style temporal video restoration.

### Model strategy

Use a legally redistributable super-resolution model such as Real-ESRGAN or a separately trained compatible model, converted and validated for Core ML. Real-ESRGAN is BSD-3-Clause licensed, but every bundled model and derivative artifact must still be checked individually before distribution.

### Required work

- Add Core ML model loading and capability detection.
- Implement `CVPixelBuffer <-> MTLTexture` conversion without unnecessary CPU copies.
- Implement RGB / YCbCr and color-range handling explicitly.
- Add FP16-capable inference where supported.
- Implement tiled inference for large frames.
- Add overlap padding and feathered tile blending to prevent seams.
- Add cancellation and progress reporting.
- Cache preview results by source frame + model + settings hash.
- Support 8-bit SDR first.
- Keep original timestamps, orientation, pixel aspect ratio, and metadata needed by the editor.

### Tiled inference

Large frames must not be processed as one monolithic tensor when memory pressure is unsafe.

Initial target:

- Tile size: dynamically selected, normally 256-512 px input tiles.
- Overlap: configurable guard region.
- Memory budget: determined from device class and active editor workload.
- Retry policy: automatically reduce tile size after recoverable allocation failure.

### MVP acceptance criteria

- 720p and 1080p H.264/HEVC inputs can be enhanced without app termination on supported devices.
- 2x output has no visible tile seams at 100% inspection.
- Cancellation releases model, texture, and temporary-buffer pressure correctly.
- Orientation, duration, frame rate, audio sync, and color appearance remain correct.
- Output is measurably different from ordinary bicubic/Lanczos resizing on a fixed restoration test set.
- The feature never silently falls back to a low-quality scaler while labeling the result as AI upscale.

---

## 5. Phase 2: Quality Profiles and Auto Enhance

### Objective

Turn the raw super-resolution backend into an editor-friendly enhancement system.

### Source analyzer

Estimate or classify:

- source resolution and scale requirement
- compression severity
- noise level
- blur / defocus severity
- ringing and halo artifacts
- face presence
- animation / game / CGI / natural footage class
- interlaced-content likelihood

### Presets

`Fast`
- lowest latency
- conservative detail reconstruction
- intended for preview and draft export

`Standard`
- balanced restoration and speed
- default local mode

`Detail`
- stronger restoration
- slower and more memory intensive

`Anime`
- tuned for line art, edges, flat-color regions, and compression around outlines

`Auto`
- source analyzer chooses a model and safe parameter set

### Controls

The UI may expose normalized 0-100 controls while the engine maps them to model-specific values. UI parameters must remain stable even if the underlying model implementation changes.

---

## 6. Phase 3: Video Temporal Consistency

### Problem

Frame-independent image super-resolution can produce flickering textures, unstable hair, crawling edges, and frame-to-frame hallucinated detail.

### Objective

Add a true video-aware path instead of simply applying an image model to every frame.

### Architecture

```text
Frames t-2 ... t+2
        |
        v
Motion Estimation / Optical Flow
        |
        v
Temporal Alignment
        |
        v
Feature or Frame Fusion
        |
        v
Restoration + Super Resolution
        |
        v
Temporal Consistency Validation
```

### Implementation options

Evaluate video-restoration architectures such as RealBasicVSR / BasicVSR++ only after the Phase 1 pipeline is stable. They should not be assumed to convert cleanly to Core ML. Unsupported operators, recurrent state, deformable alignment, memory pressure, and latency must be benchmarked on real iPhone/iPad hardware before committing to a production model.

If a full temporal network is impractical on-device, implement an intermediate temporal stabilization layer around the image SR backend using motion-aware reprojection and consistency checks.

### Acceptance criteria

- Static textures do not shimmer under normal playback.
- Fine lines and text do not crawl unnecessarily between adjacent frames.
- Scene cuts reset temporal state immediately.
- Seeking to an arbitrary frame cannot contaminate output with stale recurrent state.
- Variable-frame-rate sources retain correct presentation timestamps.

---

## 7. Phase 4: Professional Cloud Upscale

### Objective

Provide an optional highest-quality processing mode without making the editor dependent on cloud processing.

### Provider design

Create a provider abstraction so the application is not hard-wired to one vendor:

```swift
protocol CloudUpscaleProvider {
    func createJob(/* source + settings */) async throws -> /* job */
    func jobStatus(/* id */) async throws -> /* status */
    func cancelJob(/* id */) async throws
    func fetchResult(/* id */) async throws -> /* result */
}
```

The concrete Topaz provider should map After-Effects settings to the capabilities officially exposed by the Topaz API at integration time.

### Security requirements

Never place a Topaz or other commercial service secret directly inside the IPA.

Required production topology:

```text
iOS App
   |
   | authenticated request
   v
Application Backend
   |
   | vendor secret stored server-side
   v
Topaz API
```

The backend should handle:

- authenticated users / devices
- API credentials
- quota and abuse prevention
- job creation
- billing limits
- signed upload/download URLs where applicable
- cancellation
- retries with idempotency
- provider outages
- audit logs without storing sensitive media longer than necessary

### Privacy UX

Before cloud processing, clearly indicate that media will leave the device. Local mode remains available for users who do not want uploads.

### Acceptance criteria

- No vendor secret is recoverable from the app bundle.
- Interrupted uploads and downloads are resumable where the provider permits it.
- A cloud failure cannot corrupt the original project.
- The app distinguishes `Local AI` and `Professional Cloud` in the UI.
- Cost estimates or usage limits are shown before expensive jobs when practical.

---

## 8. Phase 5: Export and Timeline Integration

AI upscale must be part of the render graph rather than a destructive one-time media replacement.

### Non-destructive behavior

Store only configuration in the project:

```text
AIUpscaleConfiguration
- enabled
- targetScale / targetResolution
- modelProfile
- detailRecovery
- denoise
- compressionRepair
- sharpen
- faceRecovery
- temporalConsistency
- backendPreference
```

Original media remains untouched.

### Preview behavior

- Interactive playback may use bypass, proxy, Fast AI, or cached enhanced frames depending on device load.
- Paused preview can request a higher-quality frame.
- A small region-of-interest preview should allow fast before/after comparison.
- Preview quality and final export quality must be labeled separately.

### Export behavior

- Final export always uses the selected final-quality backend.
- Audio is passed through the existing audio pipeline without AI processing unless a separate feature explicitly modifies it.
- Video timestamps must remain authoritative.
- ProRes / HEVC / H.264 compatibility follows the normal export pipeline.

---

## 9. Phase 6: Performance, Thermal and Memory Policy

AI restoration is a heavy workload on mobile hardware. The engine must be scheduler-aware.

### Device capability tiers

At runtime derive a capability profile using:

- available Core ML compute devices
- GPU family
- memory budget
- thermal state
- low-power mode
- current project resolution and effect load

### Required policies

- dynamically reduce tile size under memory pressure
- pause or degrade background preview generation when thermal state becomes serious/critical
- avoid loading multiple large AI models simultaneously without a budget decision
- allow export to continue with a stable lower-memory execution mode instead of crashing
- record performance telemetry locally for diagnostics, without collecting user media

### Benchmark matrix

For each supported device class record:

- model load time
- first-frame latency
- steady-state ms/frame
- peak memory
- average memory
- thermal behavior over sustained export
- 720p -> 1440p
- 1080p -> 4K
- 24 / 30 / 60 fps sources

No model should become the default until real-device results meet the project's latency and stability targets.

---

## 10. Color, HDR and Alpha Requirements

### Stage A

Support SDR Rec.709 / sRGB-like workflows first, with explicit color tagging and tests.

### Stage B

Add:

- Display P3
- HDR10 / HLG where the app's color pipeline supports them
- linear-light conversion where required
- 10-bit pixel formats
- alpha-preserving paths for supported assets

AI models trained on SDR RGB must not be blindly applied to HDR transfer functions. HDR input may require a controlled working-space transform before inference and reconstruction after inference.

---

## 11. Quality Validation

Create a fixed internal regression dataset containing:

- faces
- hair and fur
- game footage
- anime / line art
- UI and small text
- foliage
- high-frequency fabric
- dark noisy footage
- heavily compressed footage
- gradients
- camera motion
- scene cuts

### Automated metrics

Where ground truth exists, track metrics such as PSNR and SSIM. Add perceptual metrics only after validating that they correlate with visual quality for the project's material.

Metrics alone are insufficient. Maintain frame crops and short video loops for human inspection of:

- hallucinated detail
- over-sharpening
- ringing
- waxy faces
- temporal flicker
- edge crawling
- color shifts
- tile seams

Every model update must run against the same regression set.

---

## 12. Failure Handling

The AI engine must fail explicitly and recoverably.

Examples:

- unsupported model -> show unavailable state and preserve project settings
- out of memory -> retry with smaller tiles or a lower-memory backend
- thermal limit -> throttle with visible status during long exports
- cloud timeout -> preserve job identity for retry/status recovery
- corrupted result -> reject it before replacing cache/export output
- model download interrupted -> verify checksum before activation

Never overwrite original media as a recovery strategy.

---

## 13. Model Distribution

If Core ML models significantly increase the application size, support versioned optional model packs.

Each model manifest should contain:

```text
modelID
semanticVersion
modelSHA256
minimumAppVersion
minimumOSVersion
supportedScaleFactors
supportedPixelFormats
estimatedMemoryClass
licenseMetadata
```

Downloaded models must be integrity-checked before loading. A failed or incompatible update must preserve the last known-good model.

---

## 14. Licensing and Compliance

Before shipping any model or integration:

- verify the code license
- verify the exact model-weight license separately
- retain required attribution/notices
- document redistribution rights
- document commercial-use rights
- do not ship proprietary Topaz model files unless a contract explicitly permits redistribution
- use the official Topaz API or licensed deployment method for Topaz processing
- document how uploaded cloud media is retained and deleted

Real-ESRGAN's repository is BSD-3-Clause licensed, but this does not automatically prove that every third-party model file or dataset-derived derivative is safe to redistribute.

---

## 15. Milestone Order

### Milestone A: Foundation

- AIUpscale module boundary
- configuration schema
- Core ML backend
- pixel-buffer/texture bridge
- capability detection
- unit tests

### Milestone B: Local 2x MVP

- first production model
- tiled inference
- seam-free compositor
- preview-region workflow
- progress and cancellation
- 720p / 1080p test coverage

### Milestone C: 4x + Auto Enhance

- 4x model/profile
- source analyzer
- presets
- automatic parameter planning
- advanced UI controls

### Milestone D: Temporal Video Quality

- motion-aware processing
- temporal cache/state
- cut detection/reset
- flicker regression tests

### Milestone E: Professional Cloud

- backend service contract
- provider abstraction
- Topaz API integration if commercially approved
- upload/job/download lifecycle
- quota, billing and privacy UX

### Milestone F: HDR / Pro Workflow

- 10-bit/HDR validation
- broader color-management integration
- professional export validation

---

## 16. Definition of Done

The feature is considered production-ready only when:

- AI processing is non-destructive and project-serializable.
- Local mode works without internet.
- Large-frame processing is memory-safe through tiling or an equivalent strategy.
- Video output maintains timestamps and A/V sync.
- No visible tile boundaries appear in the regression set.
- Temporal mode does not create obvious flicker on the regression set.
- Model and cache lifecycle survives cancellation, backgrounding, memory pressure, and relaunch.
- Cloud credentials are never embedded in the IPA.
- Cloud processing is explicitly disclosed to the user.
- Model licenses and redistribution rights are documented.
- Performance has been benchmarked on representative physical iPhone/iPad hardware.
- Preview fallbacks never misrepresent ordinary interpolation as AI enhancement.

---

## 17. Recommended First Implementation

Do **not** begin by cloning the complete Topaz Video feature set.

Start with this vertical slice:

```text
One clip
  -> AI Enhance enabled
  -> Local / Standard
  -> 2x
  -> Core ML super-resolution
  -> tiled frame processing
  -> before/after preview region
  -> normal editor export pipeline
```

Once this path is stable, add 4x, automatic analysis, video temporal consistency, and finally optional cloud processing. This keeps the architecture extensible while making the first deliverable testable on real iOS hardware.

---

## 18. References

- Topaz Labs, Image and Video Upscaling API: https://www.topazlabs.com/api
- Apple Developer Documentation, Core ML: https://developer.apple.com/documentation/coreml
- Apple Developer Documentation, Metal: https://developer.apple.com/documentation/metal
- Apple Developer Documentation, MetalFX: https://developer.apple.com/documentation/metalfx
- Real-ESRGAN repository: https://github.com/xinntao/Real-ESRGAN
- Real-ESRGAN BSD-3-Clause license: https://github.com/xinntao/Real-ESRGAN/blob/master/LICENSE
