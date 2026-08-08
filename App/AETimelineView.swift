import SwiftUI
import VertexCore
import VertexProject
import VertexTimeline

enum AETimelineInteractionError: Error, Equatable {
    case invalidScale
    case invalidFrameRate
    case overflow
}

struct AETimelineInteractionModel {
    static func moveEdit(
        layerIDs: [VertexID],
        dragPoints: Double,
        pixelsPerSecond: Double,
        frameRate: RationalTime
    ) throws -> TimelineEdit {
        .move(layerIDs: layerIDs, delta: try exactDelta(points: dragPoints, pixelsPerSecond: pixelsPerSecond, frameRate: frameRate))
    }

    static func splitEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
        .split(layerID: layerID, at: playhead)
    }

    static func snappedTime(
        proposed: RationalTime,
        candidates: [TimelineSnapCandidate],
        pixelsPerSecond: Double,
        thresholdPoints: Double = 8
    ) throws -> RationalTime {
        guard pixelsPerSecond.isFinite, pixelsPerSecond > 0 else { throw AETimelineInteractionError.invalidScale }
        return try TimelineSnapEngine().snap(
            proposedTime: proposed,
            candidates: candidates,
            thresholdPoints: thresholdPoints,
            secondsPerPoint: 1 / pixelsPerSecond
        ).snappedTime
    }

    static func exactDelta(points: Double, pixelsPerSecond: Double, frameRate: RationalTime) throws -> RationalTime {
        guard points.isFinite, pixelsPerSecond.isFinite, pixelsPerSecond > 0 else { throw AETimelineInteractionError.invalidScale }
        guard frameRate.value > 0, frameRate.value <= Int64(Int32.max), frameRate.seconds.isFinite, frameRate.seconds > 0 else {
            throw AETimelineInteractionError.invalidFrameRate
        }
        let frames = (points / pixelsPerSecond * frameRate.seconds).rounded()
        guard frames.isFinite, frames >= Double(Int64.min), frames <= Double(Int64.max) else { throw AETimelineInteractionError.overflow }
        let numerator = Int64(frames).multipliedReportingOverflow(by: Int64(frameRate.timescale))
        guard !numerator.overflow else { throw AETimelineInteractionError.overflow }
        return RationalTime(value: numerator.partialValue, timescale: Int32(frameRate.value))
    }
}

struct AETimelineView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var interactionError: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.white.opacity(0.08))
            if let composition = workspace.activeComposition {
                ruler(composition)
                Divider().overlay(Color.white.opacity(0.08))
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(workspace.orderedLayers.enumerated()), id: \.element.id) { index, layer in
                            AETimelineLayerRow(
                                layer: layer,
                                index: index,
                                composition: composition,
                                editorState: editorState,
                                interactionError: $interactionError
                            )
                            .environmentObject(workspace)
                        }
                    }
                    .frame(minWidth: 920, alignment: .leading)
                }
            } else {
                ContentUnavailableView("No Composition", systemImage: "rectangle.stack", description: Text("Create or select a composition to edit the timeline."))
                    .foregroundStyle(.secondary)
            }
            if let interactionError {
                Text(interactionError)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("Timeline")
                .font(.caption.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.accent)
            Picker("Tool", selection: $editorState.activeTool) {
                ForEach(TimelineTool.allCases, id: \.self) { tool in
                    Text(tool.rawValue.capitalized).tag(tool)
                }
            }
            .pickerStyle(.menu)
            Toggle("Snap", isOn: $editorState.snappingEnabled)
                .toggleStyle(.button)
            Button {
                splitSelectedLayer()
            } label: {
                Label("Split", systemImage: "scissors")
            }
            .disabled(editorState.selectedLayerIDs.isEmpty)
            Spacer()
            Image(systemName: "minus.magnifyingglass")
            Slider(value: $editorState.pixelsPerSecond, in: 30...480)
                .frame(width: 140)
            Image(systemName: "plus.magnifyingglass")
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func ruler(_ composition: ProjectComposition) -> some View {
        VStack(spacing: 4) {
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    Canvas { context, size in
                        let secondsStep = max(1.0 / max(composition.frameRate.seconds, 1), 40 / editorState.pixelsPerSecond)
                        var t = 0.0
                        while t <= composition.duration.seconds + 0.0001 {
                            let x = CGFloat(t * editorState.pixelsPerSecond)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: size.height - 9))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 1)
                            t += secondsStep
                        }
                    }
                    Rectangle()
                        .fill(AfterEffectsTheme.accent)
                        .frame(width: 1.5)
                        .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
                }
            }
            .frame(height: 22)

            Slider(
                value: Binding(
                    get: { editorState.playhead.seconds },
                    set: { value in
                        if let exact = workspace.exactTime(seconds: value, frameRate: composition.frameRate) {
                            editorState.setPlayhead(exact, composition: composition)
                        }
                    }
                ),
                in: 0...max(composition.duration.seconds, 0.001)
            )
            .tint(AfterEffectsTheme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func splitSelectedLayer() {
        guard let composition = workspace.activeComposition,
              let id = editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue }).first else { return }
        do {
            try workspace.commitTimelineEdit(AETimelineInteractionModel.splitEdit(layerID: id, playhead: editorState.playhead), compositionID: composition.id)
            interactionError = nil
        } catch {
            interactionError = error.localizedDescription
        }
    }
}
