# Phase 2 Core Architecture and Product Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use test-driven development for every core behavior and verify the iOS build through GitHub Actions before marking the phase complete.

**Goal:** Establish the exact, platform-neutral contracts required by every future editor subsystem and apply the approved After Effects product identity to the buildable iOS shell.

**Architecture:** `VertexCore` remains platform-neutral and owns exact time, stable identity, coordinate conversion, color metadata, dependency ordering, structured errors, milestone data, and one-time presentation policy. The SwiftUI application consumes those contracts but does not place UIKit, SwiftUI, AVFoundation, MetalPetal, or persistence types inside the core model. Product branding assets are generated deterministically from the user-supplied source image before Xcode project generation.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, XcodeGen, GitHub Actions, macOS `sips`, generated asset catalogs.

## Global Constraints

- Repository: `woo642778-art/After-Effects`.
- Base revision: Phase 1 HEAD `c7f79d0e33f78e3f0b654352ba380cacb1fee9ca`.
- Branch: `agent/phase-2-core-architecture-branding`.
- Display name: `After Effects`.
- Attribution: `Made by Maze` must appear in the startup and primary app surfaces.
- App icon and startup logo use the exact user-supplied Ae image as source material.
- Telegram URL: `https://t.me/aemotionios`.
- Telegram promotion is presented once per installation and marked consumed before presentation.
- UI without working behavior is not counted as a completed editor feature.
- Phase 2 publishes an unsigned arm64 IPA and SHA-256 checksum.

---

### Task 1: Exact rational time

**Files:**
- Create `Sources/VertexCore/RationalTime.swift`
- Create `Tests/VertexCoreTests/CoreArchitectureTests.swift`

**Produces:** `RationalTime`, `TimeRoundingMode`, and explicit overflow or invalid-timescale failures.

- [x] Write failing tests for normalization, comparison, addition, and rescaling.
- [x] Verify the tests fail because the types do not exist.
- [x] Implement normalized rational time without floating-point timeline storage.
- [x] Verify the tests pass locally.

### Task 2: Identity, geometry, color, dependency, and error contracts

**Files:**
- Create `Sources/VertexCore/VertexID.swift`
- Create `Sources/VertexCore/Geometry.swift`
- Create `Sources/VertexCore/ColorDescriptor.swift`
- Create `Sources/VertexCore/DependencyGraph.swift`
- Create `Sources/VertexCore/VertexError.swift`
- Create `Sources/VertexCore/CoreArchitectureCatalog.swift`

**Produces:** Stable UUID identity, explicit coordinate conversion, explicit color metadata, deterministic dependency evaluation, and structured diagnostic errors.

- [x] Write failing tests for each externally visible contract.
- [x] Implement the smallest complete contracts required by the tests.
- [x] Verify cycle detection and dependency ordering.
- [x] Verify coordinate conversion round trips.

### Task 3: One-time first-launch policy

**Files:**
- Create `Sources/VertexCore/OneTimePresentationGate.swift`
- Modify `Tests/VertexCoreTests/CoreArchitectureTests.swift`

**Produces:** A deterministic consume-once policy that the app maps to `@AppStorage`.

- [x] Write the failing consume-once test.
- [x] Implement the gate.
- [x] Verify first consumption returns true and all later calls return false.

### Task 4: Product identity and generated assets

**Files:**
- Create `App/Resources/AppIconSource.base64`
- Create `App/Resources/Assets.xcassets/Contents.json`
- Create `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create `App/Resources/Assets.xcassets/LaunchLogo.imageset/Contents.json`
- Create `Tools/generate_app_assets.sh`
- Modify `project.yml`

**Produces:** Deterministically generated AppIcon and LaunchLogo files derived from the supplied Ae image.

- [ ] Store the exact source image as lossless base64 text.
- [ ] Generate required iPhone, iPad, marketing, and launch-logo PNG sizes.
- [ ] Configure the app display name, bundle identifier, version, and app icon catalog.
- [ ] Verify the generated assets are included in the compiled application.

### Task 5: Startup and one-time Telegram promotion

**Files:**
- Modify `App/VertexApp.swift`
- Modify `App/RootView.swift`
- Create `App/SplashView.swift`
- Create `App/TelegramPromotionView.swift`

**Produces:** A visible startup loading surface and a once-per-installation Telegram promotion.

- [ ] Show the supplied Ae logo, `After Effects`, and `Made by Maze` during startup.
- [ ] Transition into the milestone application after the startup task finishes.
- [ ] Present the Telegram promotion once and persist consumption before showing it.
- [ ] Provide an explicit Telegram button and a non-coercive continue button.

### Task 6: Phase record and unsigned IPA automation

**Files:**
- Modify `Sources/VertexCore/Milestone.swift`
- Modify `Tests/VertexCoreTests/MilestoneTests.swift`
- Modify `.github/workflows/phase-build.yml`
- Create `Documentation/CORE_ARCHITECTURE.md`
- Create `Documentation/BRANDING_AND_FIRST_RUN.md`
- Modify `Documentation/WORK_LOG.md`
- Modify `Documentation/HANDOFF.md`

**Produces:** A complete Phase 2 record, remote test evidence, unsigned IPA, checksum, and continuation point.

- [ ] Run all `VertexCore` tests on Linux.
- [ ] Generate assets and the Xcode project on macOS.
- [ ] Build the arm64 iOS application with signing disabled.
- [ ] Verify the compiled display name and asset catalog.
- [ ] Package and upload `After-Effects-Phase-2-unsigned.ipa`.
- [ ] Inspect the downloaded IPA and record its checksum.
- [ ] Open a stacked Draft PR targeting the Phase 1 branch.
