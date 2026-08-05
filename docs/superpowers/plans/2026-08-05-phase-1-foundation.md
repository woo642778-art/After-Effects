# Phase 1 Repository Foundation Implementation Plan

> **For agentic workers:** Implement and review each task independently. Do not begin Phase 2 until the Phase 1 workflow and unsigned IPA artifact pass.

**Goal:** Establish a persistent, testable, license-aware Vertex repository with a truthful milestone app and automated unsigned IPA artifact.

**Architecture:** Product policy and progress are versioned in the repository. A platform-neutral `VertexCore` package owns typed milestone data, while a minimal SwiftUI app presents that state. XcodeGen creates the iOS project and GitHub Actions performs Apple-platform compilation and packaging.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, XcodeGen, Xcode, GitHub Actions.

## Global Constraints

- Repository: `woo642778-art/After-Effects`.
- Product vision: professional mobile motion, compositing, NLE, color, audio, tracking, AI, shape, effects, and 3D.
- UI without working behavior is not considered implementation.
- All external source use requires an explicit license and adapter boundary.
- Each buildable phase publishes an unsigned IPA and checksum.

---

### Task 1: Product and architecture record

**Files:**
- Create `Documentation/PRODUCT_VISION.md`
- Create `Documentation/ROADMAP_28_PHASES.md`
- Create `Documentation/ENGINE_INVARIANTS.md`

**Produces:** Canonical requirements that all later plans must cite and preserve.

- [x] Record product benchmarks and non-goals.
- [x] Record all 28 gated phases.
- [x] Record exact-time, render-parity, persistence, truthfulness, and source-boundary invariants.

### Task 2: Source adoption and licensing baseline

**Files:**
- Create `Documentation/SOURCE_ADOPTION_MATRIX.md`
- Create `ReferenceSources/README.md`
- Create `ThirdParty/README.md`

**Produces:** Initial adoption modes and rules for later dependency spikes.

- [x] Classify MetalPetal, VideoIO, VideoLab, Cabbage, MiniCut, and OpenTimelineIO.
- [x] Prohibit GPL source copying into the MIT product without a licensing change.
- [x] Require revision pinning and file-level review before integration.

### Task 3: Testable milestone model

**Files:**
- Create `Package.swift`
- Create `Sources/VertexCore/Milestone.swift`
- Create `Tests/VertexCoreTests/MilestoneTests.swift`

**Produces:** `MilestoneCatalog.current: Milestone` and deterministic source-boundary tests.

- [x] Write tests for phase identity, required sources, GPL isolation, and IPA policy.
- [x] Implement the smallest typed model that satisfies the tests.
- [x] Run `swift test` and verify passing results.

### Task 4: iOS milestone shell

**Files:**
- Create `App/VertexApp.swift`
- Create `App/RootView.swift`
- Create `project.yml`

**Produces:** A truthful iPhone/iPad app displaying the current repository milestone and source-adoption decisions.

- [x] Build the black, white, and red visual shell.
- [x] Bind the UI to `MilestoneCatalog.current` rather than duplicate hard-coded status.
- [x] Avoid placeholder editor controls.

### Task 5: Unsigned IPA automation

**Files:**
- Create `.github/workflows/phase-build.yml`
- Create `Documentation/BUILD_AND_IPA_POLICY.md`

**Produces:** `Vertex-Phase-1-unsigned.ipa` and SHA-256 checksum as workflow artifacts.

- [x] Run core tests on Linux.
- [x] Generate the Xcode project on macOS.
- [x] Build for generic iOS with signing disabled.
- [x] Package `Payload/Vertex.app` into an IPA.
- [x] Confirm GitHub Actions run `31015258350` succeeds.
- [x] Record artifact ID `8934224640` and IPA checksum in the work log.

### Task 6: Persistent continuation record

**Files:**
- Create `Documentation/WORK_LOG.md`
- Create `Documentation/HANDOFF.md`
- Update `README.md`

**Produces:** Enough state for a new conversation to continue without relying on hidden context.

- [x] Record implemented, verified, unverified, and excluded scope.
- [x] Record exact next actions and prohibited premature work.
- [x] Link canonical documents from the README.
