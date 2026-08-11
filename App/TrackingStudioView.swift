import SwiftUI
import VertexCore
import VertexProject
import VertexTrackingVision

struct TrackingStudioView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    var onClose: () -> Void

    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var kindRaw = ProjectTrackingKind.object.rawValue
    @State private var roiX = 0.325
    @State private var roiY = 0.325
    @State private var roiWidth = 0.35
    @State private var roiHeight = 0.35
    @State private var frameStride = 1
    @State private var minimumConfidence = 0.25
    @State private var currentTrack: ProjectMotionTrack?
    @State private var refinements: [ProjectRotoscopeRefinement] = []
    @State private var trackedMaskID: VertexID?
    @State private var isTracking = false
    @State private var trackingTask: Task<Void, Never>?
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                controls
                    .frame(minWidth: 330, idealWidth: 390, maxWidth: 440)
                Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
                resultsPanel
            }
        }
        .background(AfterEffectsTheme.background)
        .onChange(of: workspace.project?.selectedLayerID) { _, _ in
            resetAnalysis()
        }
        .onDisappear {
            trackingTask?.cancel()
            trackingTask = nil
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(AfterEffectsTheme.accent)
            Text("TRACKING / STABILIZATION / ROTOSCOPE")
                .font(.caption.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
            Spacer()
            if isTracking {
                ProgressView()
                    .controlSize(.small)
                    .tint(AfterEffectsTheme.accent)
                Button("Cancel") { cancelTracking() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(AfterEffectsTheme.elevatedPanel)
        .overlay(alignment: .bottom) { Rectangle().fill(AfterEffectsTheme.border).frame(height: 1) }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                selectedLayerCard
                trackerTypeControls
                regionControls
                samplingControls

                Button {
                    startTracking()
                } label: {
                    Label(isTracking ? "Analyzing Frames" : "Analyze Selected Layer", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AfterEffectsTheme.accent)
                .disabled(!canAnalyze || isTracking)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(statusMessage.hasPrefix("Error:") ? .orange : AfterEffectsTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
        }
        .background(AfterEffectsTheme.panel)
    }

    private var selectedLayerCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SOURCE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            if let layer = workspace.selectedLayer {
                Text(layer.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.primaryText)
                    .lineLimit(1)
                Text(sourceDescription(layer))
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            } else {
                Text("Select a media layer in the timeline first.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var trackerTypeControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("TRACKER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Picker("Tracker", selection: $kindRaw) {
                ForEach(ProjectTrackingKind.allCases, id: \.rawValue) { kind in
                    Text(displayName(kind)).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text(trackerExplanation(selectedKind))
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
    }

    private var regionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("INITIAL REGION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                Button("Center") {
                    roiWidth = 0.35
                    roiHeight = 0.35
                    roiX = 0.325
                    roiY = 0.325
                }
                .font(.caption2)
                .buttonStyle(.plain)
                Button("Full") {
                    roiX = 0
                    roiY = 0
                    roiWidth = 1
                    roiHeight = 1
                }
                .font(.caption2)
                .buttonStyle(.plain)
            }
            regionSlider("X", value: $roiX, upper: max(0, 1 - roiWidth))
            regionSlider("Y", value: $roiY, upper: max(0, 1 - roiHeight))
            regionSlider("Width", value: $roiWidth, lower: 0.03, upper: max(0.03, 1 - roiX))
            regionSlider("Height", value: $roiHeight, lower: 0.03, upper: max(0.03, 1 - roiY))
            Text("Normalized source coordinates. Face and Body use this region to choose the intended detected subject.")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.tertiaryText)
        }
        .padding(10)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var samplingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANALYSIS QUALITY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Stepper("Analyze every \(frameStride) frame\(frameStride == 1 ? "" : "s")", value: $frameStride, in: 1...8)
                .font(.caption)
            HStack {
                Text("Minimum confidence")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Slider(value: $minimumConfidence, in: 0.05...0.9)
                Text(minimumConfidence.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(10)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRACK RESULT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                if let track = currentTrack {
                    Text("\(track.samples.count) samples")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(AfterEffectsTheme.elevatedPanel)

            ScrollView {
                if let track = currentTrack {
                    VStack(alignment: .leading, spacing: 16) {
                        resultSummary(track)
                        transformApplication(track)
                        rotoscopeApplication(track)
                        sampleList(track)
                    }
                    .padding(14)
                } else {
                    ContentUnavailableView(
                        "No Tracking Result",
                        systemImage: "scope",
                        description: Text("Analyze the selected media layer. Results are generated from decoded source frames with Vision and can be applied directly to layer animation or masks.")
                    )
                    .padding(30)
                }
            }
        }
        .background(AfterEffectsTheme.background)
    }

    private func resultSummary(_ track: ProjectMotionTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(track.name)
                .font(.headline)
                .foregroundStyle(AfterEffectsTheme.primaryText)
            HStack(spacing: 22) {
                resultMetric("Samples", value: "\(track.samples.count)")
                resultMetric("Avg Confidence", value: track.averageConfidence.formatted(.number.precision(.fractionLength(3))))
                if let first = track.samples.first, let last = track.samples.last {
                    resultMetric("Duration", value: String(format: "%.2fs", last.time.seconds - first.time.seconds))
                }
            }
            if let summary = try? track.cameraMotionSummary() {
                Text(String(format: "ΔX %.3f   ΔY %.3f   Zoom %.3fx   Rotation %.2f°", summary.translationX, summary.translationY, summary.zoomRatio, summary.rotationDegrees))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func transformApplication(_ track: ProjectMotionTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSFORM SOLVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            HStack(spacing: 8) {
                Button("Apply Follow") { applyTrack(track, mode: .follow) }
                    .buttonStyle(.borderedProminent)
                    .tint(AfterEffectsTheme.accent)
                Button("Stabilize Layer") { applyTrack(track, mode: .stabilize) }
                    .buttonStyle(.bordered)
            }
            Text(track.kind == .planar
                 ? "Planar solve writes position, uniform scale, and rotation channels. Other animation channels remain intact."
                 : "Follow or stabilization writes position channels while preserving unrelated animation, effects, masks, and mattes.")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func rotoscopeApplication(_ track: ProjectMotionTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRACKED ROTOSCOPE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                Text("\(refinements.count) refinement\(refinements.count == 1 ? "" : "s")")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
            HStack(spacing: 8) {
                Button(trackedMaskID == nil ? "Create Tracked Mask" : "Update Tracked Mask") {
                    applyTrackedMask(track)
                }
                .buttonStyle(.borderedProminent)
                .tint(AfterEffectsTheme.accent)

                Button("Refine at Playhead") {
                    addRefinementAndApply(track)
                }
                .buttonStyle(.bordered)

                if !refinements.isEmpty {
                    Button("Clear Refinements") {
                        refinements = []
                        applyTrackedMask(track)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("The initial tracked region becomes an editable Bezier mask. Refine uses the current region at the nearest analyzed frame, then regenerates the real mask-path animation channel.")
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AfterEffectsTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func sampleList(_ track: ProjectMotionTrack) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SAMPLES")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            ForEach(Array(track.samples.prefix(120).enumerated()), id: \.element.id) { index, sample in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.tertiaryText)
                        .frame(width: 28, alignment: .trailing)
                    Text(sample.time.description)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 88, alignment: .leading)
                    Text(String(format: "x %.3f  y %.3f  w %.3f  h %.3f", sample.region.x, sample.region.y, sample.region.width, sample.region.height))
                        .font(.caption2.monospacedDigit())
                    Spacer()
                    Text(sample.confidence.formatted(.number.precision(.fractionLength(2))))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(sample.confidence >= minimumConfidence ? AfterEffectsTheme.secondaryText : .orange)
                }
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .padding(.vertical, 2)
            }
            if track.samples.count > 120 {
                Text("Showing first 120 of \(track.samples.count) samples")
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.tertiaryText)
            }
        }
    }

    private var selectedKind: ProjectTrackingKind {
        ProjectTrackingKind(rawValue: kindRaw) ?? .object
    }

    private var canAnalyze: Bool {
        guard let layer = workspace.selectedLayer, workspace.activeComposition != nil else { return false }
        if case .media = layer.source { return !layer.locked }
        return false
    }

    private func startTracking() {
        guard let layer = workspace.selectedLayer,
              let composition = workspace.activeComposition,
              case .media(let mediaID, _) = layer.source else {
            statusMessage = "Error: Select an unlocked media layer before tracking."
            return
        }
        let region = normalizedRegion
        let frameRate = composition.frameRate
        guard frameRate.value > 0,
              frameRate.timescale > 0,
              frameRate.value <= Int64(Int32.max) else {
            statusMessage = "Error: The composition frame rate cannot be represented exactly for tracking."
            return
        }
        let frameDuration = RationalTime(
            value: Int64(frameRate.timescale),
            timescale: Int32(frameRate.value)
        )
        let trackingEnd: RationalTime
        do {
            trackingEnd = try layer.timing.outPoint.subtracting(frameDuration)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            return
        }
        guard trackingEnd >= layer.timing.inPoint else {
            statusMessage = "Error: The selected layer must contain at least one full frame for tracking."
            return
        }
        let request = ProjectTrackingAnalysisRequest(
            kind: selectedKind,
            region: region,
            startTime: layer.timing.inPoint,
            endTime: trackingEnd,
            frameRate: frameRate,
            frameStride: frameStride,
            minimumConfidence: minimumConfidence
        )
        let sourceTimes: [RationalTime]
        do {
            _ = try request.validated()
            let compositionTimes = try request.sampleTimes()
            sourceTimes = try TrackingSourceTimeMapper.sourceTimes(
                for: layer,
                compositionTimes: compositionTimes
            )
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            return
        }

        trackingTask?.cancel()
        isTracking = true
        statusMessage = "Decoding source frames and running \(displayName(selectedKind)) tracking…"
        currentTrack = nil
        refinements = []
        trackedMaskID = nil

        trackingTask = Task { @MainActor in
            guard let url = await workspace.resolveMediaURL(mediaID) else {
                isTracking = false
                statusMessage = "Error: The selected media source could not be resolved. Relink or embed it first."
                return
            }
            do {
                let tracker = VisionMotionTracker()
                let track = try await tracker.analyze(
                    mediaURL: url,
                    request: request,
                    sourceTimes: sourceTimes
                )
                guard !Task.isCancelled else { return }
                currentTrack = track
                isTracking = false
                statusMessage = "Tracking completed with \(track.samples.count) exact timeline samples."
                trackingTask = nil
            } catch is CancellationError {
                isTracking = false
                statusMessage = "Tracking cancelled."
                trackingTask = nil
            } catch {
                isTracking = false
                statusMessage = "Error: \(error.localizedDescription)"
                trackingTask = nil
            }
        }
    }

    private func cancelTracking() {
        trackingTask?.cancel()
        trackingTask = nil
        isTracking = false
        statusMessage = "Tracking cancelled."
    }

    private func applyTrack(_ track: ProjectMotionTrack, mode: ProjectTrackingApplicationMode) {
        do {
            try workspace.applyMotionTrack(track, mode: mode, minimumConfidence: minimumConfidence)
            statusMessage = mode == .follow
                ? "Tracking transform channels were applied to the selected layer."
                : "Stabilization channels were applied to the selected layer."
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func applyTrackedMask(_ track: ProjectMotionTrack) {
        guard let referenceSample = track.samples.first else { return }
        do {
            trackedMaskID = try workspace.applyTrackedRotoscope(
                track,
                referencePath: path(for: referenceSample.region),
                referenceTime: referenceSample.time,
                minimumConfidence: minimumConfidence,
                refinements: refinements,
                maskID: trackedMaskID
            )
            statusMessage = "Tracked Bezier mask and mask-path animation were applied to the selected layer."
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func addRefinementAndApply(_ track: ProjectMotionTrack) {
        guard let nearest = track.samples.min(by: {
            abs($0.time.seconds - editorState.playhead.seconds) < abs($1.time.seconds - editorState.playhead.seconds)
        }) else { return }
        let refinement = ProjectRotoscopeRefinement(time: nearest.time, path: path(for: normalizedRegion))
        refinements.removeAll { $0.time == nearest.time }
        refinements.append(refinement)
        refinements.sort { $0.time < $1.time }
        applyTrackedMask(track)
    }

    private func resetAnalysis() {
        trackingTask?.cancel()
        trackingTask = nil
        currentTrack = nil
        refinements = []
        trackedMaskID = nil
        isTracking = false
        statusMessage = nil
    }

    private var normalizedRegion: ProjectTrackingRegion {
        let width = min(max(roiWidth, 0.03), 1)
        let height = min(max(roiHeight, 0.03), 1)
        return ProjectTrackingRegion(
            x: min(max(roiX, 0), 1 - width),
            y: min(max(roiY, 0), 1 - height),
            width: width,
            height: height
        )
    }

    private func path(for region: ProjectTrackingRegion) -> ProjectBezierPath {
        .rectangle(x: region.x, y: region.y, width: region.width, height: region.height)
    }

    private func regionSlider(
        _ title: String,
        value: Binding<Double>,
        lower: Double = 0,
        upper: Double
    ) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: lower...max(lower, upper))
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(3))))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AfterEffectsTheme.primaryText)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func resultMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(AfterEffectsTheme.primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
    }

    private func sourceDescription(_ layer: ProjectLayer) -> String {
        switch layer.source {
        case .media: "Media-backed layer • \(String(format: "%.2f", layer.timing.inPoint.seconds))–\(String(format: "%.2f", layer.timing.outPoint.seconds))s"
        default: "Tracking requires a media-backed layer"
        }
    }

    private func displayName(_ kind: ProjectTrackingKind) -> String {
        switch kind {
        case .point: "Point"
        case .planar: "Planar"
        case .object: "Object"
        case .face: "Face"
        case .body: "Body"
        }
    }

    private func trackerExplanation(_ kind: ProjectTrackingKind) -> String {
        switch kind {
        case .point: "Tracks a compact selected feature region and solves translation."
        case .planar: "Tracks a four-corner planar region and solves translation, scale, and rotation."
        case .object: "Tracks the selected object region across decoded video frames."
        case .face: "Detects the intended face near the initial region, then tracks it through the sequence."
        case .body: "Detects the intended person near the initial region, then tracks the body region through the sequence."
        }
    }
}
