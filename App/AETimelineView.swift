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

    static func trimInEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
        .trimIn(layerID: layerID, to: playhead)
    }

    static func trimOutEdit(layerID: VertexID, playhead: RationalTime) -> TimelineEdit {
        .trimOut(layerID: layerID, to: playhead)
    }

    static func rippleDeleteEdit(
        layer: ProjectLayer,
        orderedLayers: [ProjectLayer]
    ) -> TimelineEdit {
        let affected = orderedLayers
            .filter { $0.id != layer.id && $0.timing.inPoint >= layer.timing.outPoint }
            .map(\.id)
        return .rippleDelete(layerID: layer.id, affectedLayerIDs: affected)
    }

    static func adjacentFrame(
        from time: RationalTime,
        delta: Int64,
        composition: ProjectComposition
    ) throws -> RationalTime {
        guard composition.frameRate.value > 0,
              composition.frameRate.value <= Int64(Int32.max),
              composition.frameRate.timescale > 0 else {
            throw AETimelineInteractionError.invalidFrameRate
        }
        let frameDuration = RationalTime(
            value: Int64(composition.frameRate.timescale),
            timescale: Int32(composition.frameRate.value)
        )
        let scaled = frameDuration.value.multipliedReportingOverflow(by: delta)
        guard !scaled.overflow else { throw AETimelineInteractionError.overflow }
        let offset = RationalTime(value: scaled.partialValue, timescale: frameDuration.timescale)
        let candidate: RationalTime
        do {
            candidate = try time.adding(offset)
        } catch {
            throw AETimelineInteractionError.overflow
        }
        if candidate < .zero { return .zero }
        if candidate > composition.duration { return composition.duration }
        return candidate
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
    static let controlsWidth: CGFloat = 455

    @ObservedObject var editorState: EditorWorkspaceState
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var interactionError: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
            if let composition = workspace.activeComposition {
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        timelineHeader(composition)
                        Rectangle().fill(AfterEffectsTheme.border).frame(height: 1)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(workspace.orderedLayers.enumerated()), id: \.element.id) { index, layer in
                                AETimelineLayerRow(
                                    layer: layer,
                                    index: index,
                                    composition: composition,
                                    editorState: editorState,
                                    interactionError: $interactionError
                                )
                                .environmentObject(workspace)
                                Rectangle().fill(AfterEffectsTheme.border.opacity(0.55)).frame(height: 1)
                            }
                        }
                    }
                    .frame(
                        width: Self.controlsWidth + timelineWidth(composition),
                        alignment: .topLeading
                    )
                }
            } else {
                ContentUnavailableView(
                    "No Composition",
                    systemImage: "rectangle.stack",
                    description: Text("Create or select a composition to edit the timeline.")
                )
                .foregroundStyle(.secondary)
            }

            if let interactionError {
                Text(interactionError)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AfterEffectsTheme.elevatedPanel)
            }
        }
        .background(AfterEffectsTheme.panel)
    }

    private var toolbar: some View {
        HStack(spacing: 7) {
            Button {
                editorState.graphMode = editorState.graphMode == nil ? .value : nil
            } label: {
                Image(systemName: editorState.graphMode == nil ? "chart.xyaxis.line" : "list.bullet")
            }
            .help(editorState.graphMode == nil ? "Graph Editor" : "Timeline")

            Divider().frame(height: 18).overlay(AfterEffectsTheme.border)

            Button { splitSelectedLayer() } label: { Image(systemName: "scissors") }
                .disabled(selectedLayerID == nil)
                .help("Split Layer at Current Time")

            Button { duplicateSelectedLayer() } label: { Image(systemName: "plus.square.on.square") }
                .disabled(selectedLayerID == nil)
                .help("Duplicate Layer")

            Button { trimSelectedLayerIn() } label: { Image(systemName: "arrow.right.to.line.compact") }
                .disabled(selectedLayerID == nil)
                .help("Trim In to Current Time")

            Button { trimSelectedLayerOut() } label: { Image(systemName: "arrow.left.to.line.compact") }
                .disabled(selectedLayerID == nil)
                .help("Trim Out to Current Time")

            Button { rippleDeleteSelectedLayer() } label: { Image(systemName: "trash") }
                .disabled(selectedLayerID == nil)
                .help("Ripple Delete Layer")

            Divider().frame(height: 18).overlay(AfterEffectsTheme.border)

            Button { stepFrame(-1) } label: { Image(systemName: "backward.frame") }
                .disabled(workspace.activeComposition == nil)
                .help("Previous Frame")

            Button { stepFrame(1) } label: { Image(systemName: "forward.frame") }
                .disabled(workspace.activeComposition == nil)
                .help("Next Frame")

            Button { addCompositionMarker() } label: { Image(systemName: "bookmark.fill") }
                .disabled(workspace.activeComposition == nil)
                .help("Add Composition Marker at Current Time")

            Button { editorState.snappingEnabled.toggle() } label: {
                Image(systemName: editorState.snappingEnabled ? "magnet.fill" : "magnet")
            }
            .foregroundStyle(editorState.snappingEnabled ? AfterEffectsTheme.accent : AfterEffectsTheme.secondaryText)
            .help("Snapping")

            Spacer(minLength: 10)

            if let composition = workspace.activeComposition {
                Text(timecode(editorState.playhead, composition: composition))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                    .frame(minWidth: 92, alignment: .trailing)
            }

            Button { editorState.pixelsPerSecond = max(30, editorState.pixelsPerSecond / 1.25) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button { editorState.pixelsPerSecond = min(480, editorState.pixelsPerSecond * 1.25) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .font(.caption)
        .buttonStyle(.plain)
        .foregroundStyle(AfterEffectsTheme.secondaryText)
        .padding(.horizontal, 8)
        .frame(height: 31)
        .background(AfterEffectsTheme.elevatedPanel)
    }

    private var selectedLayerID: VertexID? {
        editorState.selectedLayerIDs.sorted(by: { $0.rawValue < $1.rawValue }).first
    }

    private func timelineHeader(_ composition: ProjectComposition) -> some View {
        HStack(spacing: 0) {
            layerColumnHeader
                .frame(width: Self.controlsWidth, height: 38)
            Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
            ruler(composition)
                .frame(width: timelineWidth(composition), height: 38)
        }
    }

    private var layerColumnHeader: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 24)
            Image(systemName: "speaker.wave.2").frame(width: 22)
            Text("S").frame(width: 22)
            Image(systemName: "lock").frame(width: 22)
            Image(systemName: "cube").frame(width: 22)
            Text("Layer Name / Source").frame(maxWidth: .infinity, alignment: .leading)
            Text("Mode").frame(width: 45)
            Text("TrkMat").frame(width: 48)
            Text("Parent").frame(width: 48)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(AfterEffectsTheme.secondaryText)
        .padding(.horizontal, 3)
        .background(AfterEffectsTheme.elevatedPanel)
    }

    private func ruler(_ composition: ProjectComposition) -> some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    let majorSeconds = majorTickSeconds()
                    let minorSeconds = max(1.0 / max(composition.frameRate.seconds, 1), majorSeconds / 5)
                    var t = 0.0
                    var minorIndex = 0
                    while t <= composition.duration.seconds + minorSeconds * 0.25 {
                        let x = CGFloat(t * editorState.pixelsPerSecond)
                        let isMajor = minorIndex % 5 == 0
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: isMajor ? 17 : 25))
                        path.addLine(to: CGPoint(x: x, y: 38))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(isMajor ? 0.42 : 0.18)),
                            lineWidth: 1
                        )
                        if isMajor {
                            context.draw(
                                Text(shortTime(t))
                                    .font(.system(size: 8).monospacedDigit())
                                    .foregroundStyle(AfterEffectsTheme.secondaryText),
                                at: CGPoint(x: x + 3, y: 9),
                                anchor: .topLeading
                            )
                        }
                        minorIndex += 1
                        t += minorSeconds
                    }
                }

                if let workArea = composition.workArea {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(
                            width: CGFloat(max(1, (workArea.end.seconds - workArea.start.seconds) * editorState.pixelsPerSecond)),
                            height: 4
                        )
                        .offset(x: CGFloat(workArea.start.seconds * editorState.pixelsPerSecond), y: 34)
                }

                currentTimeIndicator
                    .offset(x: CGFloat(editorState.playhead.seconds * editorState.pixelsPerSecond))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        scrub(toX: value.location.x, composition: composition)
                    }
            )
        }
        .background(AfterEffectsTheme.surface.opacity(0.65))
    }

    private var currentTimeIndicator: some View {
        VStack(spacing: 0) {
            Path { path in
                path.move(to: CGPoint(x: -5, y: 0))
                path.addLine(to: CGPoint(x: 5, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 7))
                path.closeSubpath()
            }
            .fill(AfterEffectsTheme.accent)
            .frame(width: 10, height: 7)
            Rectangle().fill(AfterEffectsTheme.accent).frame(width: 1, height: 31)
        }
    }

    private func scrub(toX x: CGFloat, composition: ProjectComposition) {
        let clamped = min(max(0, Double(x) / editorState.pixelsPerSecond), composition.duration.seconds)
        guard let exact = workspace.exactTime(seconds: clamped, frameRate: composition.frameRate) else { return }
        editorState.setPlayhead(exact, composition: composition)
    }

    private func majorTickSeconds() -> Double {
        let targetPoints = 80.0
        let raw = targetPoints / max(1, editorState.pixelsPerSecond)
        let candidates = [1.0 / 30.0, 0.1, 0.25, 0.5, 1, 2, 5, 10, 30, 60]
        return candidates.first(where: { $0 >= raw }) ?? 60
    }

    private func timelineWidth(_ composition: ProjectComposition) -> CGFloat {
        CGFloat(max(600, composition.duration.seconds * editorState.pixelsPerSecond + 80))
    }

    private func shortTime(_ seconds: Double) -> String {
        if seconds < 1 { return String(format: "%.2f", seconds) }
        if seconds < 60 { return String(format: "%.1f", seconds) }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func timecode(_ time: RationalTime, composition: ProjectComposition) -> String {
        let fps = max(1.0, composition.frameRate.seconds)
        let totalFrames = max(0, Int64((time.seconds * fps).rounded()))
        let nominal = max(1, Int64(fps.rounded()))
        let frames = totalFrames % nominal
        let totalSeconds = totalFrames / nominal
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02lld:%02lld:%02lld:%02lld", hours, minutes, seconds, frames)
    }

    private func splitSelectedLayer() {
        guard let composition = workspace.activeComposition, let id = selectedLayerID else { return }
        commit(AETimelineInteractionModel.splitEdit(layerID: id, playhead: editorState.playhead), composition: composition)
    }

    private func duplicateSelectedLayer() {
        guard let id = selectedLayerID else { return }
        workspace.selectLayer(id)
        workspace.duplicateSelectedLayer()
        interactionError = nil
    }

    private func trimSelectedLayerIn() {
        guard let composition = workspace.activeComposition, let id = selectedLayerID else { return }
        commit(AETimelineInteractionModel.trimInEdit(layerID: id, playhead: editorState.playhead), composition: composition)
    }

    private func trimSelectedLayerOut() {
        guard let composition = workspace.activeComposition, let id = selectedLayerID else { return }
        commit(AETimelineInteractionModel.trimOutEdit(layerID: id, playhead: editorState.playhead), composition: composition)
    }

    private func rippleDeleteSelectedLayer() {
        guard let composition = workspace.activeComposition,
              let id = selectedLayerID,
              let layer = workspace.orderedLayers.first(where: { $0.id == id }) else { return }
        commit(
            AETimelineInteractionModel.rippleDeleteEdit(layer: layer, orderedLayers: workspace.orderedLayers),
            composition: composition
        )
    }

    private func stepFrame(_ delta: Int64) {
        guard let composition = workspace.activeComposition else { return }
        do {
            let time = try AETimelineInteractionModel.adjacentFrame(
                from: editorState.playhead,
                delta: delta,
                composition: composition
            )
            editorState.setPlayhead(time, composition: composition)
            interactionError = nil
        } catch {
            interactionError = error.localizedDescription
        }
    }

    private func addCompositionMarker() {
        guard let composition = workspace.activeComposition,
              editorState.playhead >= .zero,
              editorState.playhead < composition.duration else { return }
        var markers = composition.markers
        let markerNumber = markers.count + 1
        markers.append(ProjectMarker(time: editorState.playhead, name: "Marker \(markerNumber)"))
        workspace.setCompositionMarkers(markers)
        interactionError = nil
    }

    private func commit(_ edit: TimelineEdit, composition: ProjectComposition) {
        do {
            try workspace.commitTimelineEdit(edit, compositionID: composition.id)
            interactionError = nil
        } catch {
            interactionError = error.localizedDescription
        }
    }
}
