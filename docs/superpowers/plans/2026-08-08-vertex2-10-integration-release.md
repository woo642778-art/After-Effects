# Vertex2 10 Integration and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the iPad workspace, 3D engine/workspace, functional export path, roadmap renumbering, and release evidence into a truthful Vertex2 10.0.0 build and unsigned IPA.

**Architecture:** The three feature plans land behind deterministic tests first. Integration then updates public version/schema/roadmap metadata, replaces iPhone release gates with iPad gates, runs portable/native/Metal/iPad/export regressions, builds a real iOS 17 arm64 Release app, packages it unsigned, audits contents, and publishes SHA-256 evidence.

**Tech Stack:** Swift 6, SwiftPM, XcodeGen, Xcode/iOS 17+, Metal, AVFoundation, GitHub Actions.

## Global Constraints

- Version: `10.0.0`.
- Build: `10`.
- Product name: `Vertex2`.
- Bundle identifier: `com.woo642778.aftereffects`.
- Minimum OS: iPadOS 17.0.
- Device family: iPad only.
- Orientations: landscape left/right only.
- Artifact name: `Vertex2-10.0.0-unsigned.ipa`.
- Completion requires real behavior, tests, iPad Simulator coverage, iOS arm64 Release compilation, IPA inspection, and SHA-256 verification.
- Existing old roadmap 10.0.0 and later versions shift forward by one; old 27.0.0 becomes 28.0.0.

---

## File Structure

- Modify `project.yml`.
- Modify `Sources/VertexCore/Milestone.swift`.
- Modify `Sources/VertexProject/ProjectSchema.swift`.
- Modify `README.md`.
- Modify `Documentation/ROADMAP_28_PHASES.md`, renaming/replacing it with `Documentation/ROADMAP_29_PHASES.md` plus compatibility note if repository links require it.
- Modify `Documentation/ROADMAP_7_TO_26.md`, replacing with a renumbered forward roadmap ending at 28.0.0 or a new correctly named canonical document.
- Modify `Documentation/VERSIONING_AND_ARTIFACTS.md`.
- Modify `Documentation/HANDOFF.md`.
- Modify `.github/workflows/phase-build.yml`.
- Modify or replace `.github/workflows/phase9-device-test-ipa.yml` with the Phase 10 iPad release workflow.
- Modify `Tools/ai/audit_ipa.py` so display-name/version checks match Vertex2 10 rather than stale `After Effects` values.
- Create `Tools/release/audit_vertex2_ipa.py` if separating release audit from AI-specific audit produces clearer ownership.
- Create `Documentation/RELEASE_10_ACCEPTANCE.md`.

### Task 1: Merge-plan preflight and dependency gate

**Files:**
- No product-code edits.

**Interfaces:**
- Consumes the completed iPad workspace, 3D, and Export plan branches/commits.
- Produces a clean integration baseline.

- [ ] **Step 1: Confirm all feature-plan tests pass independently**

Run:

```bash
swift test
xcodegen generate
```

Then run the focused app, 3D native, Metal, and Export tests named by the three subplans.

- [ ] **Step 2: Confirm `git diff --check` is clean and no feature branch contains generated DerivedData or model download cache**
- [ ] **Step 3: Integrate with fast-forward/rebase/cherry-pick according to branch topology while preserving each task commit boundary**
- [ ] **Step 4: Run `swift test` again on the combined tree**
- [ ] **Step 5: Commit only conflict-resolution changes if any are required**

### Task 2: Version and milestone identity

**Files:**
- Modify: `project.yml`
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify: `Sources/VertexCore/Milestone.swift`
- Test: `Tests/VertexCoreTests/MilestoneTests.swift`
- Test: `Tests/VertexProjectTests/ProjectSchemaMigrationTests.swift`

**Interfaces:**
- Produces consistent version/build/schema identity.

- [ ] **Step 1: Add assertions**

```swift
XCTAssertEqual(Milestone.current.number, 10)
XCTAssertEqual(ProjectDocument.currentAppVersion, "10.0.0")
```

Add a text contract requiring `MARKETING_VERSION: 10.0.0` and `CURRENT_PROJECT_VERSION: 10` in `project.yml`.

- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Set milestone to number 10 with title `iPad AE Workspace and 3D`, status `.implemented` only after all acceptance gates required by the milestone test are represented**
- [ ] **Step 4: Run core/project tests**
- [ ] **Step 5: Commit**

```bash
git add project.yml Sources/VertexCore/Milestone.swift Sources/VertexProject/ProjectSchema.swift Tests
git commit -m "chore: set Vertex2 10 release identity"
```

### Task 3: Renumber the canonical roadmap

**Files:**
- Modify: `README.md`
- Create: `Documentation/ROADMAP_29_PHASES.md`
- Modify or replace: `Documentation/ROADMAP_7_TO_26.md`
- Modify: `Documentation/HANDOFF.md`

**Interfaces:**
- Produces one unambiguous 0-28 phase sequence.

- [ ] **Step 1: Add a documentation consistency script/test under `Tests/Tools/test_roadmap_versions.py` that parses canonical tables and asserts unique versions 10 through 28 with the approved mapping**
- [ ] **Step 2: Verify the test fails against the old roadmap**
- [ ] **Step 3: Write the new sequence exactly**

```text
10.0.0 iPad AE Workspace, 2.5D/3D, Basic Mesh Editing, Functional Export Workspace
11.0.0 Time Engine and Retiming
12.0.0 Professional Color, HDR, and Scopes
13.0.0 Audio Studio
14.0.0 Text and Vector Engine
15.0.0 Tracking, Stabilization, and Rotoscoping
16.0.0 Effects Architecture
17.0.0 Advanced Pre-composition and Nesting
18.0.0 Particles and Procedural Graphics
19.0.0 Node Compositor
20.0.0 AI Studio
21.0.0 AI Upscale and Restoration
22.0.0 Asset and Preset Ecosystem
23.0.0 Advanced 3D Foundation Hardening
24.0.0 Advanced 3D Scene Workspace
25.0.0 Advanced Camera, Light, and 3D Rendering
26.0.0 Expressions, Automation, and Extensibility
27.0.0 Scale, Cache, and Final Export Architecture
28.0.0 Interchange and Release Qualification
```

Keep `Documentation/ROADMAP_28_PHASES.md` only as a short compatibility redirect pointing to `ROADMAP_29_PHASES.md`; it must not contain a conflicting old table.

- [ ] **Step 4: Run the documentation test**
- [ ] **Step 5: Commit**

```bash
git add README.md Documentation Tests/Tools/test_roadmap_versions.py
git commit -m "docs: renumber Vertex roadmap for inserted 10.0.0 release"
```

### Task 4: Fix release audit identity and broaden bundle audit

**Files:**
- Modify: `Tools/ai/audit_ipa.py` or create `Tools/release/audit_vertex2_ipa.py`
- Test: `Tests/Tools/test_audit_ipa.py`

**Interfaces:**
- Produces an audit that accepts exactly Vertex2 10 identity and checks expected AI/Metal/3D resources without stale display-name assumptions.

- [ ] **Step 1: Add a synthetic Info.plist/unit fixture asserting `CFBundleDisplayName=Vertex2`, short version `10.0.0`, build `10`, bundle ID `com.woo642778.aftereffects`, minimum OS `17.0`**
- [ ] **Step 2: Verify the stale audit fails**
- [ ] **Step 3: Update the audit to report identity values instead of hard-coding the old `After Effects` display name; require arm64 executable, no `_CodeSignature`, no `embedded.mobileprovision`, required AI model manifest/models, Metal libraries, and any packaged 3D shader bundle**
- [ ] **Step 4: Run Python tests**
- [ ] **Step 5: Commit**

### Task 5: iPad app-test matrix

**Files:**
- Modify: `.github/workflows/phase-build.yml`

**Interfaces:**
- Produces release-blocking iPad app tests.

- [ ] **Step 1: Configure simulator selection to choose available iPad devices rather than iPhone**
- [ ] **Step 2: Run app/session/workspace tests on at least two available iPad simulator sizes when runner inventory permits; otherwise one iPad simulator plus deterministic layout-resolver tests remain mandatory**
- [ ] **Step 3: Include workspace, timeline, 3D interaction, export state, launch/session persistence, and project migration tests**
- [ ] **Step 4: Upload exact xcodebuild logs on failure**
- [ ] **Step 5: Commit**

### Task 6: Portable and native regression gates

**Files:**
- Modify: `.github/workflows/phase-build.yml`

**Interfaces:**
- Produces blocking portable Swift, Python, Model I/O, Metal 2D, Metal 3D, and export-native checks.

- [ ] **Step 1: Keep full `swift test` portable coverage**
- [ ] **Step 2: Add native test filters for `VertexRenderMetalTests`, `VertexRender3DMetalTests`, `Vertex3DModelIOTests`, `VertexExportAVFoundationTests`, persistence, composition parity, and real Core ML inference**
- [ ] **Step 3: Compile both 2D and 3D `.metal` sources explicitly before tests**
- [ ] **Step 4: Run until every required gate is green without `continue-on-error` on final release blockers**
- [ ] **Step 5: Commit**

### Task 7: iOS 17 arm64 Release build

**Files:**
- Modify: Phase 10 release workflow.

**Interfaces:**
- Produces `DerivedData/Build/Products/Release-iphoneos/Vertex2.app` built for generic iOS device with iPad-only metadata.

- [ ] **Step 1: Prepare pinned AI resources and generate assets/Xcode project**
- [ ] **Step 2: Run**

```bash
xcodebuild \
  -project Vertex.xcodeproj \
  -scheme Vertex \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build
```

- [ ] **Step 3: Assert the executable is arm64 and bundle identity is exactly Vertex2/10.0.0/10/com.woo642778.aftereffects/17.0**
- [ ] **Step 4: Assert `UIDeviceFamily`/target metadata represent iPad only and supported orientations are landscape only**
- [ ] **Step 5: Commit workflow changes**

### Task 8: Package and audit unsigned IPA

**Files:**
- Modify: Phase 10 release workflow.
- Create: `Documentation/RELEASE_10_ACCEPTANCE.md`.

**Interfaces:**
- Produces `Vertex2-10.0.0-unsigned.ipa`, inventory JSON, diagnostics, and SHA-256.

- [ ] **Step 1: Package exactly**

```bash
rm -rf Payload artifacts
mkdir -p Payload artifacts
cp -R DerivedData/Build/Products/Release-iphoneos/Vertex2.app Payload/Vertex2.app
/usr/bin/zip -qry artifacts/Vertex2-10.0.0-unsigned.ipa Payload
shasum -a 256 artifacts/Vertex2-10.0.0-unsigned.ipa > artifacts/Vertex2-10.0.0-unsigned.ipa.sha256
```

- [ ] **Step 2: Run the corrected IPA audit and assert no signature/provision profile exists**
- [ ] **Step 3: Verify required AI models, 2D Metal library, 3D Metal library/resources, assets, Info.plist values, and arm64 executable are present**
- [ ] **Step 4: Record the final commit SHA, workflow run ID, artifact size, SHA-256, supported 3D import subset, export codec results, and any accepted 10.x follow-up item in `Documentation/RELEASE_10_ACCEPTANCE.md`**
- [ ] **Step 5: Upload IPA plus evidence with at least seven-day retention and commit the workflow/docs**

### Task 9: Final acceptance review

**Files:**
- No new product behavior.

**Interfaces:**
- Produces the release decision.

- [ ] **Step 1: Verify all portable tests pass**
- [ ] **Step 2: Verify iPad app tests pass**
- [ ] **Step 3: Verify native Metal/Model I/O/Export/Core ML tests pass**
- [ ] **Step 4: Verify Release build, IPA audit, and SHA-256 pass**
- [ ] **Step 5: Only then mark Milestone 10/release documentation complete and treat `Vertex2-10.0.0-unsigned.ipa` as the completed 10.0.0 artifact**
