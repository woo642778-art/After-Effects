import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VertexProject

struct CompositionWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var preview = CompositionPreviewController()
    @State private var isPNGExporterPresented = false
    @State private var compositionName = ""
    @State private var layerName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if workspace.project == nil {
                Text("Create or open a project to use Layers & Compositions.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            } else {
                compositionControls
                previewSurface
                frameNavigator
                layerToolbar
                layerList
                inspector
            }
        }
        .afterEffectsCard()
        .task { render() }
        .onChange(of: workspace.project?.revision) { _, _ in render() }
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in
            if let composition = workspace.activeComposition {
                preview.resetForComposition(composition)
                compositionName = composition.name
            }
            render()
        }
        .onChange(of: preview.frameIndex) { _, _ in render() }
        .onChange(of: workspace.project?.selectedLayerID) { _, _ in
            layerName = workspace.selectedLayer?.name ?? ""
        }
        .fileExporter(
            isPresented: $isPNGExporterPresented,
            document: preview.exportDocument,
            contentType: .png,
            defaultFilename: "After-Effects-Composition-Frame"
        ) { _ in }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAYERS & COMPOSITIONS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.accent)
                    .tracking(0.8)
                Text("Schema 2 · exact frames · multi-source Metal DAG")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
            if let composition = workspace.activeComposition {
                Text("\(composition.width)×\(composition.height)")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var compositionControls: some View {
        if let project = workspace.project {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Picker("Composition", selection: Binding(
                        get: { project.activeCompositionID ?? project.compositionRegistry[0].id },
                        set: { workspace.selectComposition($0) }
                    )) {
                        ForEach(project.compositionRegistry) { composition in
                            Text(composition.name).tag(composition.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AfterEffectsTheme.accent)

                    Button { workspace.createComposition() } label: {
                        Image(systemName: "plus")
                    }
                    Button { workspace.duplicateActiveComposition() } label: {
                        Image(systemName: "square.on.square")
                    }
                    Button(role: .destructive) { workspace.removeActiveComposition() } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(project.compositionRegistry.count <= 1)
                }
                .buttonStyle(.bordered)

                if let composition = workspace.activeComposition {
                    HStack(spacing: 8) {
                        TextField("Composition name", text: Binding(
                            get: { compositionName.isEmpty ? composition.name : compositionName },
                            set: { compositionName = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            workspace.renameActiveComposition(compositionName)
                            compositionName = ""
                        }

                        Button("Rename") {
                            workspace.renameActiveComposition(compositionName)
                            compositionName = ""
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        dimensionField("W", value: composition.width) { width in
                            workspace.setActiveCompositionDimensions(width: width, height: composition.height)
                        }
                        dimensionField("H", value: composition.height) { height in
                            workspace.setActiveCompositionDimensions(width: composition.width, height: height)
                        }
                        Text(String(format: "%.2f s", composition.duration.seconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                        Text("\(composition.frameRate.value)/\(composition.frameRate.timescale) fps")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var previewSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EXACT FRAME PREVIEW")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                Button { render() } label: { Image(systemName: "arrow.clockwise") }
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
                    ProgressView("Rendering exact frame")
                        .tint(AfterEffectsTheme.accent)
                        .foregroundStyle(.white)
                } else {
                    Text("No rendered frame")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let error = preview.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let metrics = preview.result?.metrics {
                HStack {
                    metric("Total", metrics.totalMilliseconds)
                    metric("GPU", metrics.gpuExecutionMilliseconds)
                    Spacer()
                    Text("\(metrics.expandedNodeCount) nodes · \(metrics.renderedLayerCount) layers")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }

            Button {
                isPNGExporterPresented = true
            } label: {
                Label("Export Preview PNG", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AfterEffectsTheme.accent)
            .disabled(preview.exportDocument == nil)
        }
    }

    @ViewBuilder
    private var frameNavigator: some View {
        if let composition = workspace.activeComposition {
            VStack(spacing: 8) {
                HStack {
                    Button { preview.step(by: -1, composition: composition) } label: {
                        Image(systemName: "backward.frame")
                    }
                    Button { preview.step(by: 1, composition: composition) } label: {
                        Image(systemName: "forward.frame")
                    }
                    Spacer()
                    Text("Frame \(preview.frameIndex) / \(preview.lastFrameIndex(for: composition))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .tint(AfterEffectsTheme.accent)

                Slider(
                    value: Binding(
                        get: { Double(preview.frameIndex) },
                        set: { preview.setFrameIndex(Int64($0.rounded()), composition: composition) }
                    ),
                    in: 0...Double(max(1, preview.lastFrameIndex(for: composition))),
                    step: 1
                )
                .tint(AfterEffectsTheme.accent)
            }
        }
    }

    private var layerToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYERS")
                .font(.caption.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    toolButton("Media", "film") { workspace.addSelectedMediaLayer() }
                        .disabled(workspace.selectedMedia == nil)
                    toolButton("Adjust", "slider.horizontal.3") { workspace.addAdjustmentLayer() }
                    toolButton("Null", "smallcircle.circle") { workspace.addNullLayer() }
                    toolButton("Guide", "ruler") { workspace.addGuideLayer() }
                    toolButton("Camera", "camera") { workspace.addCameraLayer() }
                    toolButton("Light", "lightbulb") { workspace.addLightLayer() }
                    if let project = workspace.project, let active = project.activeCompositionID {
                        Menu {
                            ForEach(project.compositionRegistry.filter { $0.id != active }) { composition in
                                Button(composition.name) {
                                    workspace.addNestedCompositionLayer(sourceCompositionID: composition.id)
                                }
                            }
                        } label: {
                            Label("Nested", systemImage: "rectangle.stack")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var layerList: some View {
        VStack(spacing: 6) {
            ForEach(Array(workspace.orderedLayers.enumerated()), id: \.element.id) { index, layer in
                Button {
                    workspace.selectLayer(layer.id)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                            .frame(width: 20)
                        Image(systemName: layerIcon(layer))
                            .foregroundStyle(layer.enabled ? AfterEffectsTheme.accent : .gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layer.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(layerSourceText(layer))
                                .font(.caption2)
                                .foregroundStyle(AfterEffectsTheme.secondaryText)
                        }
                        Spacer()
                        if layer.solo { Text("S").font(.caption2.bold()).foregroundStyle(.yellow) }
                        if layer.locked { Image(systemName: "lock.fill").font(.caption2) }
                    }
                    .padding(9)
                    .background(
                        workspace.project?.selectedLayerID == layer.id
                            ? AfterEffectsTheme.accent.opacity(0.16)
                            : Color.white.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Move Up") { workspace.moveLayer(layer.id, to: max(0, index - 1)) }
                        .disabled(index == 0)
                    Button("Move Down") { workspace.moveLayer(layer.id, to: min(workspace.orderedLayers.count - 1, index + 1)) }
                        .disabled(index >= workspace.orderedLayers.count - 1)
                }
            }

            if workspace.orderedLayers.isEmpty {
                Text("No layers. Select media or add a layer type above.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let layer = workspace.selectedLayer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LAYER INSPECTOR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                    Spacer()
                    Button { workspace.duplicateSelectedLayer() } label: { Image(systemName: "square.on.square") }
                    Button(role: .destructive) { workspace.removeSelectedLayer() } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.bordered)

                HStack {
                    TextField("Layer name", text: Binding(
                        get: { layerName.isEmpty ? layer.name : layerName },
                        set: { layerName = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        workspace.renameSelectedLayer(layerName)
                        layerName = ""
                    }
                    Button("Rename") {
                        workspace.renameSelectedLayer(layerName)
                        layerName = ""
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Toggle("Enabled", isOn: Binding(
                        get: { layer.enabled },
                        set: { workspace.setLayerEnabled($0) }
                    ))
                    Toggle("Solo", isOn: Binding(
                        get: { layer.solo },
                        set: { workspace.setLayerSolo($0) }
                    ))
                    Toggle("Lock", isOn: Binding(
                        get: { layer.locked },
                        set: { workspace.setLayerLocked($0) }
                    ))
                }
                .font(.caption)
                .toggleStyle(.switch)

                if !layer.locked {
                    transformControls(layer)
                    timingControls(layer)

                    if supportsPixels(layer) {
                        Picker("Blend", selection: Binding(
                            get: { layer.blendMode },
                            set: { workspace.setLayerBlendMode($0) }
                        )) {
                            ForEach(LayerBlendMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue.capitalized).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        effectControls(layer)
                    }
                } else {
                    Text("Unlock the layer to edit transform, timing, blend, or effects.")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
        } else {
            Text("Select a layer to inspect it.")
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
    }

    private func transformControls(_ layer: ProjectLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSFORM")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            valueSlider("Position X", value: layer.transform.positionX, range: -1...2) { value in
                var next = layer.transform; next.positionX = value
                workspace.setLayerTransform(next, mergeKey: "positionX")
            }
            valueSlider("Position Y", value: layer.transform.positionY, range: -1...2) { value in
                var next = layer.transform; next.positionY = value
                workspace.setLayerTransform(next, mergeKey: "positionY")
            }
            valueSlider("Scale X", value: layer.transform.scaleX, range: 0.01...4) { value in
                var next = layer.transform; next.scaleX = value
                workspace.setLayerTransform(next, mergeKey: "scaleX")
            }
            valueSlider("Scale Y", value: layer.transform.scaleY, range: 0.01...4) { value in
                var next = layer.transform; next.scaleY = value
                workspace.setLayerTransform(next, mergeKey: "scaleY")
            }
            valueSlider("Rotation", value: layer.transform.rotationDegrees, range: -180...180) { value in
                var next = layer.transform; next.rotationDegrees = value
                workspace.setLayerTransform(next, mergeKey: "rotation")
            }
            valueSlider("Opacity", value: layer.transform.opacity, range: 0...1) { value in
                var next = layer.transform; next.opacity = value
                workspace.setLayerTransform(next, mergeKey: "opacity")
            }
        }
    }

    private func timingControls(_ layer: ProjectLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIMING")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            if let composition = workspace.activeComposition {
                valueSlider("In", value: layer.timing.inPoint.seconds, range: 0...max(0.001, composition.duration.seconds)) { seconds in
                    guard let time = workspace.exactTime(seconds: seconds, frameRate: composition.frameRate),
                          time < layer.timing.outPoint else { return }
                    var next = layer.timing; next.inPoint = time
                    workspace.setLayerTiming(next)
                }
                valueSlider("Out", value: layer.timing.outPoint.seconds, range: 0...max(0.001, composition.duration.seconds)) { seconds in
                    guard let time = workspace.exactTime(seconds: seconds, frameRate: composition.frameRate),
                          time > layer.timing.inPoint else { return }
                    var next = layer.timing; next.outPoint = time
                    workspace.setLayerTiming(next)
                }
            }
        }
    }

    private func effectControls(_ layer: ProjectLayer) -> some View {
        let exposure = layer.operations.compactMap { if case .exposure(let value) = $0 { value } else { nil } }.last ?? 0
        let saturation = layer.operations.compactMap { if case .saturation(let value) = $0 { value } else { nil } }.last ?? 1
        let inverted = layer.operations.compactMap { if case .invert(let value) = $0 { value } else { nil } }.last ?? false
        return VStack(alignment: .leading, spacing: 8) {
            Text("PIXEL OPERATIONS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            valueSlider("Exposure", value: exposure, range: -4...4) { workspace.setLayerExposure($0) }
            valueSlider("Saturation", value: saturation, range: 0...3) { workspace.setLayerSaturation($0) }
            Toggle("Invert", isOn: Binding(get: { inverted }, set: { workspace.setLayerInverted($0) }))
                .font(.caption)
        }
    }

    private func dimensionField(_ label: String, value: Int, commit: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(AfterEffectsTheme.secondaryText)
            TextField("", value: Binding(get: { value }, set: commit), format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(width: 76)
        }
    }

    private func valueSlider(_ label: String, value: Double, range: ClosedRange<Double>, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
                .frame(width: 74, alignment: .leading)
            Slider(value: Binding(get: { value }, set: set), in: range)
                .tint(AfterEffectsTheme.accent)
            Text(String(format: "%.2f", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func toolButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: systemImage) }
            .buttonStyle(.bordered)
            .tint(AfterEffectsTheme.accent)
    }

    private func supportsPixels(_ layer: ProjectLayer) -> Bool {
        switch layer.source {
        case .media, .composition, .adjustment: true
        case .null, .guide, .camera, .light: false
        }
    }

    private func layerIcon(_ layer: ProjectLayer) -> String {
        switch layer.source {
        case .media: "film"
        case .adjustment: "slider.horizontal.3"
        case .null: "smallcircle.circle"
        case .guide: "ruler"
        case .camera: "camera"
        case .light: "lightbulb"
        case .composition: "rectangle.stack"
        }
    }

    private func layerSourceText(_ layer: ProjectLayer) -> String {
        switch layer.source {
        case .media: "Media"
        case .adjustment: "Adjustment"
        case .null: "Null"
        case .guide: "Guide"
        case .camera: "Camera"
        case .light: "Light"
        case .composition: "Nested Composition"
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
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
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
        preview.render(project: project, packageURL: workspace.packageURL)
    }
}
