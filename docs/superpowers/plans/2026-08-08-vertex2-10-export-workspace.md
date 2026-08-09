# Vertex2 10 Export Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a functional iPad Export workspace that renders the active composition through the same 2D/3D composition semantics as preview and writes supported delivery files with progress, cancellation, diagnostics, and iPadOS handoff.

**Architecture:** Introduce a focused export request/state model in a native AVFoundation-backed module. The app workspace only configures and observes export jobs. Frame evaluation comes from the existing composition renderer, including the new 3D scene path; export must never substitute a simplified renderer.

**Tech Stack:** Swift 6, AVFoundation, CoreMedia, CoreVideo, SwiftUI, existing VertexComposition/VertexRender/VertexMedia modules.

## Global Constraints

- H.264 and HEVC are supported only where the current platform APIs accept the requested settings.
- Frame times derive from exact rational composition timing.
- One active render job at a time is sufficient for 10.0.0.
- Cancellation must leave no file falsely represented as complete.
- Alpha export is exposed only for a tested codec/container path that actually preserves alpha.
- Export and preview use the same composition and 3D render semantics.
- Persistent multi-job queues, checkpoint/resume, proxies, and final large-project cache architecture remain later roadmap work.

---

## File Structure

- Create `Sources/VertexExport/ExportRequest.swift`.
- Create `Sources/VertexExport/ExportProgress.swift`.
- Create `Sources/VertexExport/ExportError.swift`.
- Create `Sources/VertexExportAVFoundation/AVCompositionExporter.swift`.
- Create `Sources/VertexExportAVFoundation/PixelBufferWriter.swift`.
- Create `Tests/VertexExportTests/ExportRequestTests.swift`.
- Create `Tests/VertexExportAVFoundationTests/AVCompositionExporterTests.swift`.
- Create `App/Export/ExportWorkspaceState.swift`.
- Create `App/Export/ExportWorkspaceView.swift`.
- Create `App/Export/ExportSettingsView.swift`.
- Create `App/Export/ExportProgressView.swift`.
- Create `App/Export/ExportDiagnosticsView.swift`.
- Create `Tests/VertexAppTests/ExportWorkspaceTests.swift`.

### Task 1: Portable export request validation

**Files:**
- Create: `Sources/VertexExport/ExportRequest.swift`
- Create: `Sources/VertexExport/ExportError.swift`
- Modify package manifests to expose `VertexExport`.
- Test: `Tests/VertexExportTests/ExportRequestTests.swift`

**Interfaces:**
- Produces `ExportCodec`, `ExportResolution`, `ExportRequest.validated(composition:)`.

- [ ] **Step 1: Write request validation tests**

```swift
import XCTest
@testable import VertexExport

final class ExportRequestTests: XCTestCase {
    func testCompositionNativeRequestUsesCompositionTiming() throws {
        let composition = ProjectComposition.fixture(width: 1920, height: 1080, frameRate: RationalTime(value: 30, timescale: 1))
        let request = ExportRequest(codec: .h264, width: nil, height: nil, frameRate: nil, includeAudio: true, preserveAlpha: false)
        let validated = try request.validated(composition: composition)
        XCTAssertEqual(validated.width, 1920)
        XCTAssertEqual(validated.height, 1080)
        XCTAssertEqual(validated.frameRate, composition.frameRate)
    }

    func testH264RejectsAlphaRequest() {
        let request = ExportRequest(codec: .h264, width: 1920, height: 1080, frameRate: nil, includeAudio: false, preserveAlpha: true)
        XCTAssertThrowsError(try request.validated(composition: .fixture()))
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter ExportRequestTests`
Expected: compile failure.

- [ ] **Step 3: Implement portable types**

```swift
public enum ExportCodec: String, Codable, CaseIterable, Sendable { case h264, hevc }

public struct ExportRequest: Equatable, Sendable {
    public var codec: ExportCodec
    public var width: Int?
    public var height: Int?
    public var frameRate: RationalTime?
    public var includeAudio: Bool
    public var preserveAlpha: Bool
    public var targetBitRate: Int?
}
```

Validation constrains width/height to `1...8192`, requires positive finite frame rate, requires a positive bitrate when supplied, and rejects alpha for codecs not proven to preserve it.

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

```bash
git add Package.swift Package@swift-6.0.swift Sources/VertexExport Tests/VertexExportTests
git commit -m "feat: define validated Vertex export requests"
```

### Task 2: Export progress and cancellation contract

**Files:**
- Create: `Sources/VertexExport/ExportProgress.swift`
- Test: `Tests/VertexExportTests/ExportProgressTests.swift`

**Interfaces:**
- Produces `ExportProgressSnapshot` and `ExportCancellationToken`.

- [ ] **Step 1: Write tests for monotonic bounded progress and cancellation**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement**

```swift
public struct ExportProgressSnapshot: Equatable, Sendable {
    public var completedFrames: Int64
    public var totalFrames: Int64
    public var fractionCompleted: Double {
        guard totalFrames > 0 else { return 0 }
        return min(1, max(0, Double(completedFrames) / Double(totalFrames)))
    }
}

public actor ExportCancellationToken {
    private var cancelled = false
    public func cancel() { cancelled = true }
    public func isCancelled() -> Bool { cancelled }
}
```

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

### Task 3: AVAssetWriter pixel-buffer path

**Files:**
- Create: `Sources/VertexExportAVFoundation/PixelBufferWriter.swift`
- Create: `Sources/VertexExportAVFoundation/AVCompositionExporter.swift`
- Test: `Tests/VertexExportAVFoundationTests/AVCompositionExporterTests.swift`

**Interfaces:**
- Produces `AVCompositionExporter.export(request:composition:destination:frameProvider:progress:cancellation:) async throws`.

- [ ] **Step 1: Add a 10-frame synthetic export fixture using deterministic solid-color pixel buffers**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Configure `AVAssetWriter`, video settings for `.h264`/`.hevc`, `AVAssetWriterInputPixelBufferAdaptor`, and exact `CMTime` values converted from `RationalTime` without floating-point frame accumulation**
- [ ] **Step 4: Run the native test, reopen the written asset with AVFoundation, and assert dimensions, codec family, duration, and frame count/timing tolerance**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexExportAVFoundation Tests/VertexExportAVFoundationTests Package.swift Package@swift-6.0.swift
git commit -m "feat: write exact-time Vertex video exports"
```

### Task 4: Composition renderer adapter and 3D parity

**Files:**
- Create: `App/CompositionExportFrameProvider.swift` or the equivalent native adapter under `Sources/VertexExportAVFoundation` if it does not depend on app state.
- Test: `Tests/VertexCompositionTests/ExportRenderParityTests.swift`

**Interfaces:**
- Consumes existing composition evaluator and 3D render integration.
- Produces exact-time export frames in the pixel format accepted by `PixelBufferWriter`.

- [ ] **Step 1: Add a fixture project with 2D media, an effect, a 3D object, camera, and light; render the same exact time through preview fixture and export-frame adapter**
- [ ] **Step 2: Verify the parity test fails before the adapter exists**
- [ ] **Step 3: Implement the adapter by calling the same composition render graph used by preview and performing only the necessary texture/pixel-buffer transfer**
- [ ] **Step 4: Compare deterministic fixture hashes before encoding**
- [ ] **Step 5: Commit**

### Task 5: Audio muxing where project audio is present

**Files:**
- Modify: `Sources/VertexExportAVFoundation/AVCompositionExporter.swift`
- Test: `Tests/VertexExportAVFoundationTests/AVCompositionExporterTests.swift`

**Interfaces:**
- Consumes the repository's existing media/audio providers.
- Produces synchronized audio/video when `includeAudio == true`.

- [ ] **Step 1: Add a short PCM fixture aligned to an exact composition start time**
- [ ] **Step 2: Verify the current video-only output has no audio track**
- [ ] **Step 3: Add an audio writer input and append sample buffers using existing project timing; do not resample by repeatedly converting through `Double` timestamps**
- [ ] **Step 4: Reopen output and verify one video track, one audio track, and duration agreement within one audio sample/frame boundary**
- [ ] **Step 5: Commit**

### Task 6: Transactional output and cancellation cleanup

**Files:**
- Modify: `Sources/VertexExportAVFoundation/AVCompositionExporter.swift`
- Test: `Tests/VertexExportAVFoundationTests/AVCompositionExporterTests.swift`

**Interfaces:**
- Produces temporary-file-then-atomic-finalization behavior.

- [ ] **Step 1: Add a test that cancels after frame 3 of 10 and asserts the requested final URL does not exist**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Write to a sibling temporary URL, call `cancelWriting()` on cancellation/failure, delete temporary output, and move to the final URL only after successful `finishWriting()`**
- [ ] **Step 4: Run cancellation/failure tests**
- [ ] **Step 5: Commit**

### Task 7: Export workspace state

**Files:**
- Create: `App/Export/ExportWorkspaceState.swift`
- Test: `Tests/VertexAppTests/ExportWorkspaceTests.swift`

**Interfaces:**
- Produces `ExportWorkspaceState.State` lifecycle: idle/configuring/rendering/completed/failed/cancelled.

- [ ] **Step 1: Write state transition tests**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement `@MainActor final class ExportWorkspaceState: ObservableObject` with one active `Task`, a cancellation token, validated settings, progress snapshot, destination URL, completed URL, and diagnostic error string**
- [ ] **Step 4: Run app tests**
- [ ] **Step 5: Commit**

### Task 8: AE-style Export workspace UI

**Files:**
- Create: `App/Export/ExportWorkspaceView.swift`
- Create: `App/Export/ExportSettingsView.swift`
- Create: `App/Export/ExportProgressView.swift`
- Create: `App/Export/ExportDiagnosticsView.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Test: `Tests/VertexAppTests/ExportWorkspaceTests.swift`

**Interfaces:**
- Consumes workspace preset `.export` and `ExportWorkspaceState`.
- Produces settings, preview summary, progress/cancel, diagnostics, completed-file handoff.

- [ ] **Step 1: Add compile/state tests for codec switching, custom dimensions, validation message, start/cancel button availability, and completed output URL**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement a three-region layout: left settings, center output/composition preview summary, right progress/diagnostics; use the same workspace panel chrome and adaptive resolver as the main editor**
- [ ] **Step 4: Run iPad app tests at narrow and wide widths**
- [ ] **Step 5: Commit**

```bash
git add App/Export App/IPadEditorWorkspaceView.swift Tests/VertexAppTests/ExportWorkspaceTests.swift
git commit -m "feat: add functional Vertex2 export workspace"
```

### Task 9: iPadOS file/share handoff

**Files:**
- Modify: `App/Export/ExportWorkspaceView.swift`
- Create: `App/Export/ExportFileHandoff.swift`
- Test: `Tests/VertexAppTests/ExportWorkspaceTests.swift`

**Interfaces:**
- Produces completed output through a document/share workflow without embedding app-specific private paths in project data.

- [ ] **Step 1: Add tests that handoff is enabled only for an existing completed URL**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement SwiftUI `ShareLink`/document export integration appropriate to the generated local file and preserve the original render file until user dismissal or explicit cleanup policy**
- [ ] **Step 4: Run app tests**
- [ ] **Step 5: Commit**

### Task 10: Native export acceptance gate

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Create: `Documentation/EXPORT_10_ACCEPTANCE.md`

**Interfaces:**
- Produces automated video export evidence on a macOS/iOS-native runner.

- [ ] **Step 1: Add CI coverage for request validation, native H.264 export, native HEVC export when supported by the runner, cancellation cleanup, and preview/export raw-frame parity**
- [ ] **Step 2: Run CI and preserve exact unsupported-codec diagnostics rather than forcing a false green**
- [ ] **Step 3: Document tested containers/codecs, dimensions, audio behavior, alpha behavior, cancellation behavior, and known platform capability gates**
- [ ] **Step 4: Re-run until all required supported paths are green**
- [ ] **Step 5: Commit**

```bash
git add .github/workflows/phase-build.yml Documentation/EXPORT_10_ACCEPTANCE.md
git commit -m "test: qualify Vertex2 10 export pipeline"
```
