import SwiftUI
import VertexCore
import VertexExport

struct ExportWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var controller = CompositionExportController()
    @State private var format: ExportFormat = .mov
    @State private var codec: ExportVideoCodec = .h264
    @State private var quality: ExportQualityPreset = .high
    @State private var includeAlpha = false
    @State private var resolutionPreset: ExportResolutionPreset = .matchComposition
    @State private var customWidth = 3840
    @State private var customHeight = 2160
    @State private var lockOutputAspectRatio = true
    @State private var frameRatePreset: ExportFrameRatePreset = .matchComposition
    @State private var customFrameRateText = "60"
    @State private var outputError: String?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                settingsPanel
                    .frame(width: min(360, max(290, proxy.size.width * 0.27)))
                divider
                summaryPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                divider
                progressPanel
                    .frame(width: min(360, max(285, proxy.size.width * 0.27)))
            }
            .background(AfterEffectsTheme.background)
        }
        .onAppear { syncCustomOutputWithComposition() }
        .onChange(of: workspace.activeComposition?.id) { _, _ in syncCustomOutputWithComposition() }
        .onChange(of: format) { _, next in normalizeCodec(for: next) }
        .onChange(of: codec) { _, next in
            if next != .proRes4444 { includeAlpha = false }
        }
        .onChange(of: resolutionPreset) { _, _ in
            outputError = nil
            preferHighResolutionCodecIfNeeded()
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

                    Divider().overlay(AfterEffectsTheme.border)
                    settingLabel("Resolution")
                    Picker("Resolution", selection: $resolutionPreset) {
                        ForEach(ExportResolutionPreset.allCases, id: \.self) { preset in
                            Text(resolutionName(preset)).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    if resolutionPreset == .custom {
                        HStack(spacing: 8) {
                            TextField("Width", value: customWidthBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                            Text("×")
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                            TextField("Height", value: customHeightBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Lock Aspect Ratio", isOn: $lockOutputAspectRatio)
                            .font(.caption)
                    }

                    settingLabel("Output Frame Rate")
                    HStack(spacing: 8) {
                        Picker("Frame Rate", selection: $frameRatePreset) {
                            ForEach(ExportFrameRatePreset.allCases, id: \.self) { rate in
                                Text(frameRateName(rate)).tag(rate)
                            }
                        }
                        .pickerStyle(.menu)
                        if frameRatePreset == .custom {
                            TextField("fps", text: $customFrameRateText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 84)
                        }
                    }

                    if let composition = workspace.activeComposition {
                        VStack(alignment: .leading, spacing: 6) {
                            settingLabel("Resolved Output")
                            if let resolved = resolvedOutput(for: composition) {
                                exportRow("Resolution", "\(resolved.dimensions.width) × \(resolved.dimensions.height)")
                                exportRow("Frame Rate", String(format: "%.3f fps", resolved.frameRate.seconds))
                                exportRow("Duration", String(format: "%.2f s", composition.duration.seconds))
                                if resolved.dimensions.width > 4096 || resolved.dimensions.height > 2160 {
                                    Text("High-resolution export uses the full render graph at the selected dimensions. HEVC or ProRes is recommended for 5K–8K video output.")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Text("Enter a valid custom resolution and frame rate.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if format == .mov && codec == .proRes4444 {
                        Toggle("Preserve Alpha", isOn: $includeAlpha)
                            .font(.caption)
                    }

                    if let outputError {
                        Text(outputError)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Preview and export evaluate the same composition graph. Resolution and frame rate may match the composition or be overridden per render.")
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
                    if let resolved = resolvedOutput(for: composition) {
                        Text("\(resolved.dimensions.width) × \(resolved.dimensions.height) · \(String(format: "%.3f", resolved.frameRate.seconds)) fps")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                    }
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
                    .disabled(workspace.activeComposition == nil || workspace.activeComposition.flatMap(resolvedOutput(for:)) == nil)
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
        guard let settings = makeOutputSettings() else {
            outputError = "Custom frame rate must be a finite value from 1 to 240 fps, and resolution must be within 1...8192 pixels per side."
            return
        }
        do {
            _ = try settings.resolved(
                compositionDimensions: ExportDimensions(width: composition.width, height: composition.height),
                compositionFrameRate: composition.frameRate
            )
            outputError = nil
            controller.start(
                project: project,
                packageURL: workspace.packageURL,
                composition: composition,
                format: format,
                codec: format.isVideoContainer ? codec : nil,
                quality: quality,
                includeAlpha: includeAlpha,
                outputSettings: settings
            )
        } catch {
            outputError = "Output resolution must be within 1...8192 pixels per side and frame rate within 1...240 fps."
        }
    }

    private func resolvedOutput(for composition: ProjectComposition) -> ResolvedExportOutputSettings? {
        guard let settings = makeOutputSettings() else { return nil }
        return try? settings.resolved(
            compositionDimensions: ExportDimensions(width: composition.width, height: composition.height),
            compositionFrameRate: composition.frameRate
        )
    }

    private func makeOutputSettings() -> ExportOutputSettings? {
        let customRate: RationalTime?
        if frameRatePreset == .custom {
            guard let value = Double(customFrameRateText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  value.isFinite, value >= 1, value <= 240 else { return nil }
            let timescale: Int32 = 1_000_000
            let numerator = Int64((value * Double(timescale)).rounded())
            guard numerator > 0, numerator <= Int64(Int32.max) else { return nil }
            customRate = RationalTime(value: numerator, timescale: timescale)
        } else {
            customRate = nil
        }
        return ExportOutputSettings(
            resolution: resolutionPreset,
            customDimensions: ExportDimensions(width: customWidth, height: customHeight),
            frameRate: frameRatePreset,
            customFrameRate: customRate
        )
    }

    private var customWidthBinding: Binding<Int> {
        Binding(
            get: { customWidth },
            set: { newValue in
                let oldWidth = max(1, customWidth)
                let ratio = Double(customHeight) / Double(oldWidth)
                customWidth = newValue
                if lockOutputAspectRatio {
                    customHeight = max(1, min(8192, Int((Double(newValue) * ratio).rounded())))
                }
            }
        )
    }

    private var customHeightBinding: Binding<Int> {
        Binding(
            get: { customHeight },
            set: { newValue in
                let oldHeight = max(1, customHeight)
                let ratio = Double(customWidth) / Double(oldHeight)
                customHeight = newValue
                if lockOutputAspectRatio {
                    customWidth = max(1, min(8192, Int((Double(newValue) * ratio).rounded())))
                }
            }
        )
    }

    private func syncCustomOutputWithComposition() {
        guard let composition = workspace.activeComposition else { return }
        customWidth = composition.width
        customHeight = composition.height
        customFrameRateText = String(format: "%.6g", composition.frameRate.seconds)
    }

    private func preferHighResolutionCodecIfNeeded() {
        guard format.isVideoContainer, codec == .h264 else { return }
        let dimensions = resolutionPreset.dimensions
        if let dimensions, dimensions.width > 4096 {
            codec = .hevc
        }
    }

    private func normalizeCodec(for format: ExportFormat) {
        if !format.isVideoContainer { includeAlpha = false; return }
        if !allowedCodecs.contains(codec) { codec = .h264 }
        if format != .mov { includeAlpha = false }
        preferHighResolutionCodecIfNeeded()
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

    private func resolutionName(_ preset: ExportResolutionPreset) -> String {
        switch preset {
        case .matchComposition: "Match Composition"
        case .hd720: "HD 720p — 1280 × 720"
        case .hd1080: "Full HD — 1920 × 1080"
        case .qhd1440: "QHD — 2560 × 1440"
        case .uhd4K: "UHD 4K — 3840 × 2160"
        case .dci4K: "DCI 4K — 4096 × 2160"
        case .uhd5K: "5K — 5120 × 2880"
        case .uhd6K: "6K — 6144 × 3456"
        case .uhd8K: "UHD 8K — 7680 × 4320"
        case .dci8K: "DCI 8K — 8192 × 4320"
        case .custom: "Custom"
        }
    }

    private func frameRateName(_ preset: ExportFrameRatePreset) -> String {
        switch preset {
        case .matchComposition: "Match Composition"
        case .fps23976: "23.976"
        case .fps24: "24"
        case .fps25: "25"
        case .fps2997: "29.97"
        case .fps30: "30"
        case .fps50: "50"
        case .fps5994: "59.94"
        case .fps60: "60"
        case .fps120: "120"
        case .custom: "Custom"
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
