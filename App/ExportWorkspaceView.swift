import SwiftUI
import VertexExport

struct ExportWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var controller = CompositionExportController()
    @State private var format: ExportFormat = .mov
    @State private var codec: ExportVideoCodec = .h264
    @State private var quality: ExportQualityPreset = .high
    @State private var includeAlpha = false

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                settingsPanel
                    .frame(width: min(330, max(260, proxy.size.width * 0.24)))
                divider
                summaryPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                divider
                progressPanel
                    .frame(width: min(360, max(285, proxy.size.width * 0.27)))
            }
            .background(AfterEffectsTheme.background)
        }
        .onChange(of: format) { _, next in normalizeCodec(for: next) }
        .onChange(of: codec) { _, next in
            if next != .proRes4444 { includeAlpha = false }
        }
    }

    private var settingsPanel: some View {
        AEPanel(title: "Export Settings", systemImage: "slider.horizontal.3") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    settingLabel("Format")
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { value in
                            Text(formatName(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)

                    if format.isVideoContainer {
                        settingLabel("Codec")
                        Picker("Codec", selection: $codec) {
                            ForEach(allowedCodecs, id: \.self) { value in
                                Text(codecName(value)).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    settingLabel("Quality")
                    Picker("Quality", selection: $quality) {
                        ForEach(ExportQualityPreset.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let composition = workspace.activeComposition {
                        VStack(alignment: .leading, spacing: 6) {
                            settingLabel("Output")
                            exportRow("Resolution", "\(composition.width) × \(composition.height)")
                            exportRow("Frame Rate", String(format: "%.3f fps", composition.frameRate.seconds))
                            exportRow("Duration", String(format: "%.2f s", composition.duration.seconds))
                        }
                    }

                    if format == .mov && codec == .proRes4444 {
                        Toggle("Preserve Alpha", isOn: $includeAlpha)
                            .font(.caption)
                    }

                    Text("Export evaluates every frame through the same composition graph and AI effect path used by the editor preview.")
                        .font(.caption2)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            }
        }
    }

    private var summaryPanel: some View {
        AEPanel(title: "Output", systemImage: "film.stack") {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: controller.isRunning ? "waveform.path.ecg.rectangle" : "rectangle.stack.badge.play")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(AfterEffectsTheme.accent)
                if let composition = workspace.activeComposition {
                    Text(composition.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AfterEffectsTheme.primaryText)
                    Text("\(composition.width) × \(composition.height) · \(String(format: "%.3f", composition.frameRate.seconds)) fps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                    Text("\(formatName(format)) · \(format.isVideoContainer ? codecName(codec) : quality.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                } else {
                    Text("No active composition")
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }

    private var progressPanel: some View {
        AEPanel(title: "Render Queue", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                switch controller.state {
                case .idle:
                    statusText("Ready")
                case .rendering:
                    statusText("Rendering")
                    ProgressView(value: controller.progress.fractionCompleted)
                        .tint(AfterEffectsTheme.accent)
                    exportRow("Frames", "\(controller.progress.completedFrames) / \(controller.progress.totalFrames)")
                    exportRow("Progress", "\(Int((controller.progress.fractionCompleted * 100).rounded()))%")
                case .completed:
                    statusText("Completed")
                    if let url = controller.completedURL {
                        Text(url.lastPathComponent)
                            .font(.caption2.monospaced())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                            .lineLimit(3)
                        ShareLink(item: url) {
                            Label("Share Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .failed:
                    statusText("Failed")
                    Text(controller.errorMessage ?? "Unknown export failure")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                case .cancelled:
                    statusText("Cancelled")
                }

                Spacer()

                if controller.isRunning {
                    Button(role: .destructive) { controller.cancel() } label: {
                        Label("Cancel Export", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { beginExport() } label: {
                        Label("Export Composition", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(workspace.activeComposition == nil)
                }
            }
            .padding(12)
        }
    }

    private var divider: some View { Rectangle().fill(AfterEffectsTheme.border).frame(width: 1) }

    private var allowedCodecs: [ExportVideoCodec] {
        switch format {
        case .mp4: [.h264, .hevc]
        case .mov: ExportVideoCodec.allCases
        default: []
        }
    }

    private func beginExport() {
        guard let project = workspace.project, let composition = workspace.activeComposition else { return }
        controller.start(
            project: project,
            packageURL: workspace.packageURL,
            composition: composition,
            format: format,
            codec: format.isVideoContainer ? codec : nil,
            quality: quality,
            includeAlpha: includeAlpha
        )
    }

    private func normalizeCodec(for format: ExportFormat) {
        if !format.isVideoContainer { includeAlpha = false; return }
        if !allowedCodecs.contains(codec) { codec = .h264 }
        if format != .mov { includeAlpha = false }
    }

    private func formatName(_ format: ExportFormat) -> String {
        switch format {
        case .mov: "QuickTime MOV"
        case .mp4: "MPEG-4 MP4"
        case .gif: "Animated GIF"
        case .pngSequence: "PNG Sequence"
        case .jpegSequence: "JPEG Sequence"
        }
    }

    private func codecName(_ codec: ExportVideoCodec) -> String {
        switch codec {
        case .h264: "H.264"
        case .hevc: "HEVC"
        case .proRes422: "Apple ProRes 422"
        case .proRes4444: "Apple ProRes 4444"
        }
    }

    private func settingLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(AfterEffectsTheme.secondaryText)
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AfterEffectsTheme.primaryText)
    }

    private func exportRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(AfterEffectsTheme.secondaryText)
            Spacer()
            Text(value).foregroundStyle(AfterEffectsTheme.primaryText)
        }
        .font(.caption2.monospacedDigit())
    }
}
