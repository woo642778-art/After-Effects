import Foundation
import Testing
@testable import Vertex

@Test("Wide iPad workspace keeps both AE side docks visible")
func wideWorkspaceKeepsBothDocks() {
    let metrics = AEWorkspaceLayoutPolicy.metrics(
        containerWidth: 1366,
        containerHeight: 940,
        preset: .standard,
        leftFraction: 0.22,
        rightFraction: 0.27,
        timelineFraction: 0.32
    )

    #expect(metrics.widthBand == .wide)
    #expect(metrics.showsLeftDock)
    #expect(metrics.showsRightDock)
    #expect(!metrics.leftDockUsesTabs)
    #expect((230...360).contains(metrics.leftDockWidth))
    #expect((300...440).contains(metrics.rightDockWidth))
}

@Test("Medium iPad workspace consolidates left panels into tabs")
func mediumWorkspaceUsesTabbedLeftDock() {
    let metrics = AEWorkspaceLayoutPolicy.metrics(
        containerWidth: 1100,
        containerHeight: 760,
        preset: .standard,
        leftFraction: 0.24,
        rightFraction: 0.28,
        timelineFraction: 0.33
    )

    #expect(metrics.widthBand == .medium)
    #expect(metrics.showsLeftDock)
    #expect(metrics.showsRightDock)
    #expect(metrics.leftDockUsesTabs)
}

@Test("Narrow Stage Manager workspace preserves composition and timeline by hiding side docks")
func narrowWorkspaceHidesSideDocks() {
    let metrics = AEWorkspaceLayoutPolicy.metrics(
        containerWidth: 900,
        containerHeight: 700,
        preset: .standard,
        leftFraction: 0.22,
        rightFraction: 0.27,
        timelineFraction: 0.34
    )

    #expect(metrics.widthBand == .narrow)
    #expect(!metrics.showsLeftDock)
    #expect(!metrics.showsRightDock)
    #expect((210...340).contains(metrics.timelineHeight))
}

@Test("Minimal workspace hides chrome-heavy side panels even on a wide iPad")
func minimalWorkspaceHidesSidePanels() {
    let metrics = AEWorkspaceLayoutPolicy.metrics(
        containerWidth: 1366,
        containerHeight: 940,
        preset: .minimal,
        leftFraction: 0.22,
        rightFraction: 0.27,
        timelineFraction: 0.32
    )

    #expect(!metrics.showsLeftDock)
    #expect(!metrics.showsRightDock)
}

@Test("Workspace split fractions are clamped to safe bounds")
func workspaceFractionsClampSafely() {
    let metrics = AEWorkspaceLayoutPolicy.metrics(
        containerWidth: 1366,
        containerHeight: 940,
        preset: .standard,
        leftFraction: 0.99,
        rightFraction: 0.99,
        timelineFraction: 0.99
    )

    #expect(metrics.leftDockWidth <= 360)
    #expect(metrics.rightDockWidth <= 440)
    #expect(metrics.timelineHeight <= 410)
}

@Test("Workspace preset selection persists outside project data")
@MainActor
func workspacePresetPersistsInUserDefaults() {
    let suiteName = "AEWorkspaceLayoutTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = EditorWorkspaceState(userDefaults: defaults)
    first.setWorkspace(.effects, userDefaults: defaults)

    let second = EditorWorkspaceState(userDefaults: defaults)
    #expect(second.activeWorkspace == .effects)
}
