import SwiftUI
import UniformTypeIdentifiers
import VertexAI

struct AIWorkspaceView: View {
    @StateObject private var model = AIWorkspaceViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("OFFLINE AI STUDIO", systemImage: "brain.head.profile")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Text("7.0")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

            Picker("AI Tool", selection: $model.tool) {
                ForEach(AIWorkspaceViewModel.Tool.allCases) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            Button {
                isImporterPresented = true
            } label: {
                HStack {
                    Image(systemName: "film.stack")
                    Text(model.sourceName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "folder")
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.state == .running)

            qualityControls
            taskControls
            executionControls
            status
            resultSection
        }
        .afterEffectsCard()
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.chooseSource(url) }
            case .failure:
                break
            }
        }
    }

    private var qualityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUALITY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Picker("Quality", selection: $model.requestedTier) {
                Text("Preview").tag(AIQualityTier.preview)
                Text("Balanced").tag(AIQualityTier.balanced)
                Text("Max").tag(AIQualityTier.maxQuality)
            }
            .pickerStyle(.segmented)
            .disabled(model.state == .running)

            if model.state == .running || model.state == .completed {
                HStack {
                    Text("Active: \(label(model.effectiveTier))")
                    Spacer()
                    Text(model.activeModel)
                        .lineLimit(1)
                }
                .font(.caption.monospaced())
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            if let reason = model.fallbackReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var taskControls: some View {
        switch model.tool {
        case .depth:
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Invert depth", isOn: $model.depthInvert)
                valueSlider("Smoothing", value: $model.depthSmoothing)
                valueSlider("Edge refinement", value: $model.depthEdgeRefinement)
                valueSlider("Temporal consistency", value: $model.depthTemporalSmoothing)
                Text("Generates a viewable depth video plus float32 depth sidecars for verified chunks.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

        case .cutout:
            VStack(alignment: .leading, spacing: 10) {
                Picker("Cutout Mode", selection: $model.cutoutMode) {
                    Text("Person").tag(CutoutMode.personFast)
                    Text("Foreground").tag(CutoutMode.foregroundFast)
                    Text("Point Select").tag(CutoutMode.promptQuality)
                }
                .pickerStyle(.segmented)
                if model.cutoutMode == .promptQuality {
                    valueSlider("Point X", value: $model.promptX)
                    valueSlider("Point Y", value: $model.promptY)
                    Text("Point coordinates are normalized. The selected foreground instance is propagated frame-by-frame with temporal smoothing.")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                valueSlider("Feather", value: $model.cutoutFeather)
                valueSlider("Edge cleanup", value: $model.cutoutEdgeCleanup)
                valueSlider("Temporal consistency", value: $model.cutoutTemporalSmoothing)
                Text("Cutout is encoded as HEVC-with-alpha. Unsupported alpha encoders fail explicitly instead of flattening transparency.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

        case .upscale:
            VStack(alignment: .leading, spacing: 10) {
                Picker("Scale", selection: $model.upscaleScale) {
                    Text("1× Restore").tag(1.0)
                    Text("2×").tag(2.0)
                    Text("3×").tag(3.0)
                    Text("4×").tag(4.0)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Tile overlap")
                    Slider(value: $model.upscaleOverlap, in: 8...96, step: 8)
                    Text("\(Int(model.upscaleOverlap))")
                        .monospacedDigit()
                        .frame(width: 32)
                }
                .font(.caption)
                Text("Real-ESRGAN x4v3 runs fully on-device. Dedicated Anime/Game mode remains hidden until a separate checkpoint passes the same license and native-quality gates.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

        case .restoration:
            VStack(alignment: .leading, spacing: 10) {
                valueSlider("Denoise", value: $model.denoise)
                valueSlider("Compression cleanup", value: $model.artifactRemoval)
                valueSlider("Detail recovery", value: $model.detailRecovery)
                Text("Balanced uses a bounded pass. Max Quality can chain validated denoise + detail reconstruction. Deblur and Face Restore are not labeled supported until dedicated models pass native validation.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
    }

    private var executionControls: some View {
        HStack(spacing: 10) {
            if model.state == .running {
                Button(role: .destructive) {
                    model.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    model.start()
                } label: {
                    Label(model.state == .cancelled ? "Resume" : "Process Full Video", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canStart)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if model.state == .running || model.progress > 0 {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: model.progress)
                Text(model.progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        if case .failed(let message) = model.state {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let url = model.resultURL, let descriptor = model.resultDescriptor {
            Divider().overlay(.white.opacity(0.12))
            VStack(alignment: .leading, spacing: 8) {
                Label("Verified AI output", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                Text("\(descriptor.width)×\(descriptor.height) · \(descriptor.frameCount) frames")
                    .font(.caption.monospaced())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Text(url.lastPathComponent)
                    .font(.caption2.monospaced())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .textSelection(.enabled)
                ShareLink(item: url) {
                    Label("Export / Open in Files", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func valueSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 126, alignment: .leading)
            Slider(value: value, in: 0...1)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .frame(width: 38)
        }
        .font(.caption)
    }

    private func label(_ tier: AIQualityTier) -> String {
        switch tier {
        case .preview: "Preview"
        case .balanced: "Balanced"
        case .maxQuality: "Max"
        }
    }
}
