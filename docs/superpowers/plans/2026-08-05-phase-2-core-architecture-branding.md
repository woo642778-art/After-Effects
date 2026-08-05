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

- [x] Write failing tests for normalization, comparison, addition, and rescaling.
- [x] Implement normalized rational time without floating-point timeline storage.
- [x] Replace iOS 18-only `Int128` arithmetic with checked iOS 17-compatible `Int64` arithmetic and continued-fraction comparison.
- [x] Add extreme-value comparison and signed-rounding regression tests.
- [x] Verify 11 Phase 2 core tests pass locally and remotely.

### Task 2: Identity, geometry, color, dependency, and error contracts

- [x] Implement stable UUID identity.
- [x] Implement explicit coordinate conversion and round-trip tests.
- [x] Implement explicit color metadata.
- [x] Implement deterministic dependency ordering and cycle detection.
- [x] Implement structured diagnostic errors.

### Task 3: One-time first-launch policy

- [x] Write and pass the consume-once test.
- [x] Map the tested gate to `@AppStorage`.

### Task 4: Product identity and generated assets

- [x] Store the exact source image as lossless base64 text.
- [x] Generate required iPhone, iPad, marketing, and launch-logo PNG sizes.
- [x] Configure the app display name, bundle identifier, version, and app icon catalog.
- [x] Verify `Assets.car` and generated icon PNG files are included in the compiled application.

### Task 5: Startup and one-time Telegram promotion

- [x] Show the supplied Ae logo, `After Effects`, and `Made by Maze` during startup.
- [x] Transition into the milestone application after the startup task finishes.
- [x] Present the Telegram promotion once and persist consumption before showing it.
- [x] Provide an explicit Telegram button and a non-coercive continue button.

### Task 6: Phase record and unsigned IPA automation

- [x] Run all `VertexCore` tests on Linux.
- [x] Generate assets and the Xcode project on macOS.
- [x] Build the arm64 iOS application with signing disabled.
- [x] Verify the compiled display name and asset catalog.
- [x] Package and upload `After-Effects-Phase-2-unsigned.ipa`.
- [x] Inspect the downloaded IPA and record its checksum.
- [x] Open stacked Draft PR #2 targeting the Phase 1 branch.
- [x] Exclude documentation-only changes from unnecessary IPA rebuilds.

## Final Evidence

- Final source and CI HEAD: `0aef837a7ca6dba72fa7228b7ebcde903e371dd5`.
- Successful workflow run: `31019377690`.
- Artifact ID: `8935962354`.
- Artifact archive digest: `sha256:cc2f642f35fa1c38e4510f026bf5baf6b6a2c9c28f86647bb4fa72c79ac7f830`.
- Extracted IPA SHA-256: `de21e8749af68726683a4ec277a28b187b7b484f949846cea1dcf1e97bf9fd42`.
- Verified executable: `Payload/AfterEffects.app/AfterEffects`, 64-bit arm64 Mach-O.
- Verified display name: `After Effects`.
- Verified bundle identifier: `com.woo642778.aftereffects`.
- Verified version: `0.2.0 (2)`.
