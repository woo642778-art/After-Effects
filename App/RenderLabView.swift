import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VertexMedia
import VertexRender

struct RenderLabView: View {
    @EnvironmentObject private var projectWorkspace: ProjectWorkspaceViewModel
    @StateObject private var viewModel: RenderLabViewModel
    @State private var isExporterPresented = false

    init(source: PortableImage) {
        _viewModel = StateObject(wrappedValue: RenderLabViewModel(source: source))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GPU RENDER LAB")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                        .tracking(0.8)
                    Text("One graph · Metal preview · identical PNG export")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Spacer()
                Button {
                    viewModel.renderNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(AfterEffectsTheme.accent)
            }

            preview
            controls

            if let metrics = viewModel.metrics {
                metricsView(metrics)
            }

            Button {
                isExporterPresented = true
            } label: {
                Label("Export Exact Preview PNG", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AfterEffectsTheme.accent)
            .disabled(viewModel.exportDocument == nil)
        }
        .padding(.top, 4)
        .task {
            viewModel.attach(projectWorkspace)
            viewModel.start()
        }
        .onChange(of: projectWorkspace.project?.projectID.rawValue) { _, _ in
            viewModel.attach(projectWorkspace)
        }
        .fileExporter(
            isPresented: $isExporterPresented,
            document: viewModel.exportDocument,
            contentType: .png,
            defaultFilename: "After-Effects-Render"
        ) { _ in }
    }

    @ViewBuilder
    private var preview: some View {
        switch viewModel.state {
        case .idle, .rendering:
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .aspectRatio(
                        max(1, viewModel.source.pixelSize.width) / max(1, viewModel.source.pixelSize.height),
                        contentMode: .fit
                    )
                ProgressView("Rendering with Metal")
                    .tint(AfterEffectsTheme.accent)
                    .foregroundStyle(.white)
            }

        case .rendered(let result):
            if let image = UIImage(data: result.image.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(checkerboard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            parameterSlider("Exposure", value: $viewModel.exposure, range: -3...3, suffix: " stops")
            parameterSlider("Saturation", value: $viewModel.saturation, range: 0...2, suffix: "×")
            parameterSlider("Opacity", value: $viewModel.opacity, range: 0...1, suffix: "")
            parameterSlider("Scale", value: $viewModel.scale, range: 0.5...2, suffix: "×")
            parameterSlider("Move X", value: $viewModel.translationX, range: -0.5...0.5, suffix: "")
            parameterSlider("Move Y", value: $viewModel.translationY, range: -0.5...0.5, suffix: "")

            Toggle("Invert RGB", isOn: $viewModel.inverted)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .tint(AfterEffectsTheme.accent)

            Picker("Output", selection: $viewModel.outputLongEdge) {
                Text("720").tag(720)
                Text("1080").tag(1080)
                Text("1440").tag(1440)
                Text("2160").tag(2160)
            }
            .pickerStyle(.segmented)
        }
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))) + suffix)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Slider(value: value, in: range)
                .tint(AfterEffectsTheme.accent)
        }
    }

    private func metricsView(_ metrics: RenderMetrics) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                metric("Total", value: metrics.totalMilliseconds)
                Spacer()
                metric("CPU", value: metrics.cpuEncodingMilliseconds)
                Spacer()
                metric("GPU", value: metrics.gpuExecutionMilliseconds)
            }
            if let cacheKey = viewModel.cacheKey {
                Text("Cache · \(cacheKey.prefix(16))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metric(_ name: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            Text(value.map { String(format: "%.2f ms", $0) } ?? "n/a")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            for row in 0...Int(size.height / cell) {
                for column in 0...Int(size.width / cell) {
                    let shade = (row + column).isMultiple(of: 2) ? 0.10 : 0.16
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                        with: .color(.white.opacity(shade))
                    )
                }
            }
        }
    }
}
