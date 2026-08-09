import SwiftUI

enum AEWorkspacePreset: String, CaseIterable, Identifiable, Sendable {
    case standard
    case minimal
    case effects
    case threeD
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .minimal: "Minimal"
        case .effects: "Effects"
        case .threeD: "3D"
        case .export: "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "rectangle.3.group"
        case .minimal: "rectangle.inset.filled"
        case .effects: "slider.horizontal.3"
        case .threeD: "cube"
        case .export: "square.and.arrow.up"
        }
    }
}

enum AEWorkspaceWidthBand: String, Equatable, Sendable {
    case narrow
    case medium
    case wide
}

struct AEWorkspaceMetrics: Equatable, Sendable {
    let widthBand: AEWorkspaceWidthBand
    let leftDockWidth: CGFloat
    let rightDockWidth: CGFloat
    let timelineHeight: CGFloat
    let showsLeftDock: Bool
    let showsRightDock: Bool
    let leftDockUsesTabs: Bool
}

enum AEWorkspaceLayoutPolicy {
    static let wideThreshold: CGFloat = 1_180
    static let mediumThreshold: CGFloat = 980

    static func metrics(
        containerWidth width: CGFloat,
        containerHeight height: CGFloat,
        preset: AEWorkspacePreset,
        leftFraction: CGFloat,
        rightFraction: CGFloat,
        timelineFraction: CGFloat
    ) -> AEWorkspaceMetrics {
        let safeWidth = max(1, width)
        let safeHeight = max(1, height)
        let band: AEWorkspaceWidthBand = if safeWidth >= wideThreshold {
            .wide
        } else if safeWidth >= mediumThreshold {
            .medium
        } else {
            .narrow
        }

        let normalizedLeft = leftFraction.clamped(to: 0.16...0.30)
        let normalizedRight = rightFraction.clamped(to: 0.20...0.36)
        let normalizedTimeline = timelineFraction.clamped(to: 0.24...0.46)

        let leftRange: ClosedRange<CGFloat> = band == .wide ? 230...360 : 220...310
        let rightRange: ClosedRange<CGFloat> = band == .wide ? 300...440 : 270...360
        let timelineRange: ClosedRange<CGFloat> = band == .narrow ? 210...340 : 220...410

        var showLeft = band != .narrow
        var showRight = band != .narrow

        switch preset {
        case .minimal:
            showLeft = false
            showRight = false
        case .export:
            showLeft = false
            showRight = band != .narrow
        case .effects:
            showRight = band != .narrow
        case .standard, .threeD:
            break
        }

        let requestedLeft = safeWidth * normalizedLeft
        let requestedRight = safeWidth * normalizedRight
        let requestedTimeline = safeHeight * normalizedTimeline

        return AEWorkspaceMetrics(
            widthBand: band,
            leftDockWidth: requestedLeft.clamped(to: leftRange),
            rightDockWidth: requestedRight.clamped(to: rightRange),
            timelineHeight: requestedTimeline.clamped(to: timelineRange),
            showsLeftDock: showLeft,
            showsRightDock: showRight,
            leftDockUsesTabs: band == .medium
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
