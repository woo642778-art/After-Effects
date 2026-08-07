import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VertexProject
import VertexRender

struct CompositionWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var preview = CompositionPreviewController()
    @State private var isPNGExporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if workspace.project == nil {
                Text("Create or open a project to use the composition workspace.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            } else {
                CompositionHeaderView()
                Divider().overlay(Color.white.opacity(0.1))
                previewSurface

                if let composition = workspace.activeComposition {
                    ExactFrameNavigatorView(preview: preview, composition: composition)
                }

                Divider().overlay(Color.white.opacity(0.1))
                LayerListView(frameIndex: preview.frameIndex)
                Divider().overlay(Color.white.opacity(0.1))
                LayerInspectorView()
            }
        }
        .afterEffectsCard()
        .task { render() }
        .onChange(of: workspace.project?.revision) { _, _ in render() }
        .onChange(of: preview.frameIndex) { _, _ in render() }
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in
            if let composition = workspace.activeComposition {
                preview.resetForComposition(composition)
            }
            render()
        }
        .fileExporter(
            isPresented: $isPNGExporterPresented,
            document: preview.exportDocument,
            contentType: .png,
            defaultFilename: "After-Effects-Composition-Frame"
        ) { _ in }
    }

    private var previewSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("COMPOSITION PREVIEW")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                        .tracking(0.8)
                    Text("One DAG · one Metal result · identical PNG")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Spacer()
                Button { render() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(AfterEffectsTheme.accent)
            }

            ZStack {
                checkerboard
                if let result = preview.result, let image = UIImage(data: result.image.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if preview.isRendering {
                    ProgressView("Compiling and rendering exact frame")
                        .tint(AfterEffectsTheme.accent)
                        .foregroundStyle(.white)
                } else {
                    Text("No rendered frame")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }

                if preview.isRendering, preview.result != nil {
                    ProgressView()
                        .tint(AfterEffectsTheme.accent)
                        .padding(10)
                        .background(.black.opacity(0.55), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                }
            }
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let message = preview.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if let metrics = preview.result?.metrics {
                HStack {
                    metric("Total", metrics.totalMilliseconds)
                    Spacer()
                    metric("GPU", metrics.gpuExecutionMilliseconds)
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Graph")
                        Text("\(metrics.expandedNodeCount) nodes · \(metrics.renderedLayerCount) layers")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .font(.caption2)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                isPNGExporterPresented = true
            } label: {
                Label("Export Exact Preview PNG", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AfterEffectsTheme.accent)
            .disabled(preview.exportDocument == nil)
        }
    }

    private var previewAspectRatio: Double {
        guard let composition = workspace.activeComposition else { return 1 }
        return Double(composition.width) / Double(max(1, composition.height))
    }

    private func metric(_ name: String, _ value: Double?) -> some View {
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
                    let shade = (row + column).isMultiple(of: 2) ? 0.08 : 0.14
                    context.fill(
                        Path(CGRect(
                            x: CGFloat(column) * cell,
                            y: CGFloat(row) * cell,
                            width: cell,
                            height: cell
                        )),
                        with: .color(.white.opacity(shade))
                    )
                }
            }
        }
        .background(Color.black.opacity(0.35))
    }

    private func render() {
        guard let project = workspace.project else {
            preview.cancel()
            return
        }
        preview.render(project: project, packageURL: workspace.packageLocation)
    }
}
