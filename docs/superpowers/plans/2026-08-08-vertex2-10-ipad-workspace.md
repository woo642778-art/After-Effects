# Vertex2 10 iPad AE Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Vertex2 into an iPad-only, landscape-only, adaptive AE-style workspace that remains usable across supported iPad sizes, Stage Manager widths, external displays, touch, Pencil, pointer, and keyboard.

**Architecture:** Keep the existing project, timeline, preview, effect, and command models. Replace the fixed `IPadEditorWorkspaceView` HStack/VStack shell with a separate workspace-layout state and panel host. Layout persistence is UI preference state, never canonical `.vertexproject` state.

**Tech Stack:** Swift 6, SwiftUI, iPadOS 17+, XcodeGen, existing VertexProject/VertexTimeline/VertexRender modules.

## Global Constraints

- Product version for the integrated release is `10.0.0`, build `10`.
- Bundle identifier remains `com.woo642778.aftereffects`.
- Deployment target remains iPadOS `17.0`.
- Shipping device family is iPad only: `TARGETED_DEVICE_FAMILY: "2"`.
- Supported interface orientations are `UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight` only.
- No important panel may rely on a single fixed screen width.
- No compact state may compress labels into one-character vertical columns.
- Existing project/timeline/render engines must be reused rather than duplicated.
- Workspace layout preferences must not mutate project revision or `.vertexproject` contents.

---

## File Structure

- Modify `project.yml`: iPad-only family/orientations and 10.0.0 identity during integration.
- Modify `App/EditorWorkspaceState.swift`: remove iPhone-only compact panel state and add workspace selection hooks only where editor-wide state belongs.
- Replace `App/IPadEditorWorkspaceView.swift`: top-level adaptive shell.
- Create `App/Workspace/WorkspacePreset.swift`: Standard/Minimal/Effects/ThreeD/Export identity.
- Create `App/Workspace/WorkspaceLayoutState.swift`: normalized split positions, collapsed panels, active tabs, persistence.
- Create `App/Workspace/WorkspaceLayoutResolver.swift`: width/height band calculation and clamped dimensions.
- Create `App/Workspace/WorkspacePanel.swift`: panel IDs and metadata.
- Create `App/Workspace/WorkspacePanelHost.swift`: AE-style panel header and tab host.
- Create `App/Workspace/WorkspaceSplitHandle.swift`: drag-resizable divider.
- Create `App/Workspace/WorkspaceToolbar.swift`: tools, preset switcher, export/3D entry points.
- Create `App/Workspace/ProjectDockView.swift`: Project and Effects & Presets left dock.
- Create `App/Workspace/InspectorDockView.swift`: Effect Controls/Properties right dock.
- Create `Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift`.
- Create `Tests/VertexAppTests/WorkspaceStatePersistenceTests.swift`.
- Create `Tests/VertexAppTests/IPadWorkspaceContractTests.swift`.

### Task 1: iPad-only platform contract

**Files:**
- Modify: `project.yml`
- Test: `Tests/VertexAppTests/IPadWorkspaceContractTests.swift`

**Interfaces:**
- Consumes: current XcodeGen target `Vertex`.
- Produces: an iPad-only application target with landscape-only orientation metadata.

- [ ] **Step 1: Write the failing platform contract test**

```swift
import XCTest

final class IPadWorkspaceContractTests: XCTestCase {
    func testShippingTargetIsIPadLandscapeOnly() throws {
        let text = try String(contentsOfFile: "project.yml", encoding: .utf8)
        XCTAssertTrue(text.contains("TARGETED_DEVICE_FAMILY: \"2\""))
        XCTAssertTrue(text.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"))
        XCTAssertFalse(text.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone:"))
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `swift test --filter IPadWorkspaceContractTests`
Expected: FAIL because the current target still contains device family `1,2` and iPhone orientation metadata.

- [ ] **Step 3: Change the target settings**

Set exactly:

```yaml
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
TARGETED_DEVICE_FAMILY: "2"
```

Remove `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` from the app target.

- [ ] **Step 4: Regenerate the project and run the test**

Run: `xcodegen generate && swift test --filter IPadWorkspaceContractTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add project.yml Tests/VertexAppTests/IPadWorkspaceContractTests.swift
git commit -m "feat: make Vertex2 iPad landscape only"
```

### Task 2: Workspace panel and preset model

**Files:**
- Create: `App/Workspace/WorkspacePreset.swift`
- Create: `App/Workspace/WorkspacePanel.swift`
- Test: `Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift`

**Interfaces:**
- Produces: `WorkspacePreset`, `WorkspacePanelID`, `WorkspacePanelPlacement`.

- [ ] **Step 1: Write model tests**

```swift
import XCTest
@testable import Vertex

final class WorkspaceLayoutResolverTests: XCTestCase {
    func testStandardPresetContainsCoreAEPanels() {
        XCTAssertEqual(
            Set(WorkspacePreset.standard.defaultPanels),
            [.project, .effectsAndPresets, .composition, .effectControls, .timeline]
        )
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `xcodebuild -project Vertex.xcodeproj -scheme Vertex -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' test -only-testing:VertexAppTests/WorkspaceLayoutResolverTests`
Expected: compile failure because the workspace types do not exist.

- [ ] **Step 3: Add the types**

```swift
import Foundation

enum WorkspacePreset: String, CaseIterable, Codable, Sendable {
    case standard
    case minimal
    case effects
    case threeD
    case export

    var defaultPanels: [WorkspacePanelID] {
        switch self {
        case .standard: [.project, .effectsAndPresets, .composition, .effectControls, .timeline]
        case .minimal: [.composition, .timeline]
        case .effects: [.effectsAndPresets, .composition, .effectControls, .timeline]
        case .threeD: [.scene, .composition, .properties, .timeline]
        case .export: [.exportSettings, .exportPreview, .exportDiagnostics]
        }
    }
}

enum WorkspacePanelID: String, CaseIterable, Codable, Hashable, Sendable {
    case project
    case effectsAndPresets
    case composition
    case effectControls
    case properties
    case timeline
    case scene
    case exportSettings
    case exportPreview
    case exportDiagnostics
}

enum WorkspacePanelPlacement: String, Codable, Sendable {
    case left
    case center
    case right
    case bottom
    case overlay
}
```

- [ ] **Step 4: Run the test**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspacePreset.swift App/Workspace/WorkspacePanel.swift Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift
git commit -m "feat: define Vertex2 workspace panels and presets"
```

### Task 3: Adaptive layout resolver

**Files:**
- Create: `App/Workspace/WorkspaceLayoutResolver.swift`
- Modify: `Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift`

**Interfaces:**
- Produces: `WorkspaceWidthBand`, `WorkspaceResolvedLayout`, `WorkspaceLayoutResolver.resolve(size:state:)`.

- [ ] **Step 1: Add boundary tests**

```swift
func testWidthBandsAreContentDriven() {
    XCTAssertEqual(WorkspaceLayoutResolver.band(forWidth: 900), .narrow)
    XCTAssertEqual(WorkspaceLayoutResolver.band(forWidth: 980), .medium)
    XCTAssertEqual(WorkspaceLayoutResolver.band(forWidth: 1180), .wide)
}

func testResolvedSplitsAreClamped() {
    var state = WorkspaceLayoutState.default
    state.leftFraction = 0.8
    state.rightFraction = 0.8
    let resolved = WorkspaceLayoutResolver.resolve(size: CGSize(width: 1366, height: 1024), state: state)
    XCTAssertGreaterThan(resolved.compositionWidth, 420)
    XCTAssertLessThanOrEqual(resolved.leftWidth, 360)
    XCTAssertLessThanOrEqual(resolved.rightWidth, 420)
}
```

- [ ] **Step 2: Verify failure**

Run the workspace layout test target.
Expected: compile failure until the resolver/state exist.

- [ ] **Step 3: Implement resolver contracts**

```swift
import CoreGraphics

enum WorkspaceWidthBand: Equatable { case narrow, medium, wide }

struct WorkspaceResolvedLayout: Equatable {
    var band: WorkspaceWidthBand
    var leftWidth: CGFloat
    var rightWidth: CGFloat
    var timelineHeight: CGFloat
    var compositionWidth: CGFloat
    var showLeftDock: Bool
    var showRightDock: Bool
}

enum WorkspaceLayoutResolver {
    static func band(forWidth width: CGFloat) -> WorkspaceWidthBand {
        if width < 980 { return .narrow }
        if width < 1180 { return .medium }
        return .wide
    }

    static func resolve(size: CGSize, state: WorkspaceLayoutState) -> WorkspaceResolvedLayout {
        let band = band(forWidth: size.width)
        let showLeft = band != .narrow && !state.leftCollapsed
        let showRight = band != .narrow && !state.rightCollapsed
        let left = showLeft ? min(max(size.width * state.leftFraction, 220), 360) : 0
        let right = showRight ? min(max(size.width * state.rightFraction, 260), 420) : 0
        let timeline = min(max(size.height * state.timelineFraction, 220), size.height * 0.48)
        return WorkspaceResolvedLayout(
            band: band,
            leftWidth: left,
            rightWidth: right,
            timelineHeight: timeline,
            compositionWidth: max(0, size.width - left - right),
            showLeftDock: showLeft,
            showRightDock: showRight
        )
    }
}
```

- [ ] **Step 4: Run tests and adjust only clamp constants if a supported iPad test fixture proves unusable**

Expected: PASS at 900/980/1180 and standard 1024/1194/1366 landscape widths.

- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspaceLayoutResolver.swift Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift
git commit -m "feat: resolve adaptive iPad workspace layouts"
```

### Task 4: Workspace preference state and persistence

**Files:**
- Create: `App/Workspace/WorkspaceLayoutState.swift`
- Create: `Tests/VertexAppTests/WorkspaceStatePersistenceTests.swift`

**Interfaces:**
- Produces: `WorkspaceLayoutState`, `WorkspacePreferencesStore`.

- [ ] **Step 1: Write round-trip tests**

```swift
import XCTest
@testable import Vertex

final class WorkspaceStatePersistenceTests: XCTestCase {
    func testWorkspaceStateRoundTripsWithoutProjectDocument() throws {
        let suite = "WorkspaceStatePersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspacePreferencesStore(defaults: defaults)
        var state = WorkspaceLayoutState.default
        state.preset = .threeD
        state.timelineFraction = 0.41
        state.leftCollapsed = true
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
    }
}
```

- [ ] **Step 2: Verify failure**

Expected: compile failure.

- [ ] **Step 3: Implement normalized state**

```swift
struct WorkspaceLayoutState: Codable, Equatable, Sendable {
    var preset: WorkspacePreset
    var leftFraction: Double
    var rightFraction: Double
    var timelineFraction: Double
    var leftCollapsed: Bool
    var rightCollapsed: Bool
    var activeLeftTab: WorkspacePanelID
    var activeRightTab: WorkspacePanelID

    static let `default` = WorkspaceLayoutState(
        preset: .standard,
        leftFraction: 0.22,
        rightFraction: 0.25,
        timelineFraction: 0.32,
        leftCollapsed: false,
        rightCollapsed: false,
        activeLeftTab: .project,
        activeRightTab: .effectControls
    )
}

struct WorkspacePreferencesStore {
    private let defaults: UserDefaults
    private let key = "Vertex2.WorkspaceLayout.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func save(_ state: WorkspaceLayoutState) throws { defaults.set(try JSONEncoder().encode(state), forKey: key) }
    func load() throws -> WorkspaceLayoutState {
        guard let data = defaults.data(forKey: key) else { return .default }
        return try JSONDecoder().decode(WorkspaceLayoutState.self, from: data)
    }
}
```

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspaceLayoutState.swift Tests/VertexAppTests/WorkspaceStatePersistenceTests.swift
git commit -m "feat: persist adaptive workspace preferences"
```

### Task 5: AE panel chrome and split handles

**Files:**
- Create: `App/Workspace/WorkspacePanelHost.swift`
- Create: `App/Workspace/WorkspaceSplitHandle.swift`

**Interfaces:**
- Produces reusable SwiftUI panel shell and normalized split drag callbacks.

- [ ] **Step 1: Add a compile contract through `IPadWorkspaceContractTests`**

Instantiate `WorkspacePanelHost(title: "Project") { EmptyView() }` and `WorkspaceSplitHandle(axis: .vertical, onDelta: { _ in })` in test-only compile helpers.

- [ ] **Step 2: Run app tests and verify compile failure**

- [ ] **Step 3: Implement neutral AE-style chrome**

`WorkspacePanelHost` must use a near-black content surface, a compact title row, a 1-point separator, clipping at the panel boundary, and no hard-coded content width. `WorkspaceSplitHandle` must expose a minimum 12-point hit target while drawing a 1-point divider and report drag deltas without owning project state.

- [ ] **Step 4: Run app tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspacePanelHost.swift App/Workspace/WorkspaceSplitHandle.swift Tests/VertexAppTests/IPadWorkspaceContractTests.swift
git commit -m "feat: add resizable AE style workspace panels"
```

### Task 6: Left and right docks

**Files:**
- Create: `App/Workspace/ProjectDockView.swift`
- Create: `App/Workspace/InspectorDockView.swift`

**Interfaces:**
- Consumes existing `ProjectWorkspaceView`, `MediaImportView`, `EffectControlsView`.
- Produces tabbed left/right panel contents with narrow-mode drawer compatibility.

- [ ] **Step 1: Add compile tests that construct both dock views with bindings to `WorkspaceLayoutState`**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement Project/Effects tabs on the left and Effect Controls/Properties tabs on the right without duplicating existing feature views**
- [ ] **Step 4: Run app tests**
- [ ] **Step 5: Commit**

```bash
git add App/Workspace/ProjectDockView.swift App/Workspace/InspectorDockView.swift Tests/VertexAppTests/IPadWorkspaceContractTests.swift
git commit -m "feat: compose Vertex2 project and inspector docks"
```

### Task 7: Top toolbar and workspace switching

**Files:**
- Create: `App/Workspace/WorkspaceToolbar.swift`
- Modify: `App/EditorWorkspaceState.swift`

**Interfaces:**
- Produces: preset selection, tool actions, 3D and Export workspace entry events.

- [ ] **Step 1: Add tests that preset changes do not alter `ProjectDocument.revision`**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Add `@Published var workspacePreset: WorkspacePreset = .standard` to editor UI state and bind the toolbar selector to it**
- [ ] **Step 4: Verify tests**
- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspaceToolbar.swift App/EditorWorkspaceState.swift Tests/VertexAppTests/IPadWorkspaceContractTests.swift
git commit -m "feat: add Vertex2 workspace toolbar and presets"
```

### Task 8: Replace the fixed iPad workspace shell

**Files:**
- Replace: `App/IPadEditorWorkspaceView.swift`

**Interfaces:**
- Consumes: `WorkspaceLayoutResolver`, `WorkspaceLayoutState`, existing preview/timeline/docks.
- Produces: responsive Standard/Minimal/Effects shell and routing placeholders for `.threeD` and `.export` that must be replaced by their dedicated plans before 10.0.0 completion.

- [ ] **Step 1: Add resolver-backed view contract tests for narrow/medium/wide visibility decisions**
- [ ] **Step 2: Verify old fixed shell fails those tests**
- [ ] **Step 3: Rebuild `IPadEditorWorkspaceView` with `GeometryReader` and resolved layout values; center Composition and bottom `AETimelineView` remain primary in every band**
- [ ] **Step 4: Test 900, 1024, 1194, 1366, and 1600-point widths; assert no core panel receives a negative or zero-width composition region**
- [ ] **Step 5: Commit**

```bash
git add App/IPadEditorWorkspaceView.swift Tests/VertexAppTests/WorkspaceLayoutResolverTests.swift
git commit -m "feat: rebuild Vertex2 as adaptive AE workspace"
```

### Task 9: Pointer, keyboard, touch and Pencil affordances

**Files:**
- Modify: `App/Workspace/WorkspaceSplitHandle.swift`
- Modify: `App/Workspace/WorkspaceToolbar.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`

**Interfaces:**
- Produces keyboard commands, pointer-safe resize hit areas, touch-safe controls; Pencil-specific precision is consumed later by the 3D plan.

- [ ] **Step 1: Add tests for command identifiers and nonzero hit-region constants**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Add keyboard shortcuts for playback/tool/preset actions through SwiftUI commands or focused actions and pointer hover feedback on split handles**
- [ ] **Step 4: Run iPad app tests**
- [ ] **Step 5: Commit**

```bash
git add App/Workspace/WorkspaceSplitHandle.swift App/Workspace/WorkspaceToolbar.swift App/IPadEditorWorkspaceView.swift Tests/VertexAppTests/IPadWorkspaceContractTests.swift
git commit -m "feat: optimize Vertex2 workspace input for iPad"
```

### Task 10: iPad simulator workspace QA gate

**Files:**
- Modify: `.github/workflows/phase-build.yml`

**Interfaces:**
- Produces: iPad Simulator app-test matrix replacing iPhone-specific release gating.

- [ ] **Step 1: Add workflow assertions that select an available iPad simulator and reject iPhone-only destinations**
- [ ] **Step 2: Verify workflow syntax locally where available with `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/phase-build.yml")'`**
- [ ] **Step 3: Run the app-test suite on at least one compact iPad simulator and one large iPad simulator**
- [ ] **Step 4: Capture screenshots/log evidence for Standard workspace at narrow and wide window sizes**
- [ ] **Step 5: Commit**

```bash
git add .github/workflows/phase-build.yml
git commit -m "ci: validate Vertex2 adaptive iPad workspace"
```
