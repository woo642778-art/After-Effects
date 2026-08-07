import SwiftUI
import VertexCore
import VertexProject

struct LayerInspectorView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var name = ""
    @State private var startSeconds = 0.0
    @State private var inSeconds = 0.0
    @State private var outSeconds = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSPECTOR")
                .font(.caption.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.accent)
                .tracking(0.8)

            if let layer = workspace.selectedLayer {
                Toggle("Locked", isOn: Binding(
                    get: { layer.locked },
                    set: { workspace.setLayerLocked($0) }
                ))
                .tint(AfterEffectsTheme.accent)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Layer name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { workspace.renameSelectedLayer(name) }
                        Button("Rename") { workspace.renameSelectedLayer(name) }
                            .buttonStyle(.bordered)
                    }

                    HStack {
                        Toggle("Enabled", isOn: boolBinding(\.enabled, workspace.setLayerEnabled))
                        Toggle("Solo", isOn: boolBinding(\.solo, workspace.setLayerSolo))
                    }
                    .tint(AfterEffectsTheme.accent)

                    timingEditor(layer)

                    if case .adjustment = layer.source {
                        slider("Adjustment Mix", value: transformBinding(\.opacity, key: "transform.opacity"), range: 0...1)
                        operationControls(layer)
                    } else if layer.source.isModelOnly {
                        modelOnlyControls(layer)
                    } else {
                        transformControls(layer)
                        blendControl(layer)
                        operationControls(layer)
                        nestedControls(layer)
                    }
                }
                .disabled(layer.locked)
                .opacity(layer.locked ? 0.55 : 1)
            } else {
                Text("Select a layer to edit its durable schema 2 properties.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .onAppear(perform: sync)
        .onChange(of: workspace.project?.selectedLayerID) { _, _ in sync() }
    }

    private func timingEditor(_ layer: ProjectLayer) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("TIMING · seconds, snapped to exact frames")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            HStack {
                numberField("Start", value: $startSeconds)
                numberField("In", value: $inSeconds)
                numberField("Out", value: $outSeconds)
            }
            Button("Apply Timing") {
                guard let composition = workspace.activeComposition,
                      let start = workspace.exactTime(seconds: startSeconds, frameRate: composition.frameRate),
                      let inPoint = workspace.exactTime(seconds: inSeconds, frameRate: composition.frameRate),
                      let outPoint = workspace.exactTime(seconds: outSeconds, frameRate: composition.frameRate) else { return }
                workspace.setLayerTiming(LayerTiming(startTime: start, inPoint: inPoint, outPoint: outPoint))
            }
            .buttonStyle(.bordered)
        }
    }

    private func transformControls(_ layer: ProjectLayer) -> some View {
        VStack(spacing: 10) {
            slider("Position X", value: transformBinding(\.positionX, key: "transform.positionX"), range: -1...2)
            slider("Position Y", value: transformBinding(\.positionY, key: "transform.positionY"), range: -1...2)
            slider("Anchor X", value: transformBinding(\.anchorX, key: "transform.anchorX"), range: 0...1)
            slider("Anchor Y", value: transformBinding(\.anchorY, key: "transform.anchorY"), range: 0...1)
            slider("Scale X", value: transformBinding(\.scaleX, key: "transform.scaleX"), range: 0.05...4)
            slider("Scale Y", value: transformBinding(\.scaleY, key: "transform.scaleY"), range: 0.05...4)
            slider("Rotation", value: transformBinding(\.rotationDegrees, key: "transform.rotation"), range: -180...180)
            slider("Opacity", value: transformBinding(\.opacity, key: "transform.opacity"), range: 0...1)
        }
    }

    private func blendControl(_ layer: ProjectLayer) -> some View {
        Picker("Blend Mode", selection: Binding(
            get: { layer.blendMode },
            set: { workspace.setLayerBlendMode($0) }
        )) {
            ForEach(LayerBlendMode.allCases, id: \.self) { mode in
                Text(mode.rawValue.capitalized).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private func operationControls(_ layer: ProjectLayer) -> some View {
        VStack(spacing: 10) {
            slider("Exposure", value: Binding(
                get: { exposure(layer) },
                set: { workspace.setLayerExposure($0) }
            ), range: -4...4)
            slider("Saturation", value: Binding(
                get: { saturation(layer) },
                set: { workspace.setLayerSaturation($0) }
            ), range: 0...4)
            Toggle("Invert RGB", isOn: Binding(
                get: { inverted(layer) },
                set: { workspace.setLayerInverted($0) }
            ))
            .tint(AfterEffectsTheme.accent)
        }
    }

    @ViewBuilder
    private func nestedControls(_ layer: ProjectLayer) -> some View {
        if case .composition(let sourceID, let sourceStart) = layer.source {
            VStack(alignment: .leading, spacing: 8) {
                Text("NESTED COMPOSITION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                Menu(workspace.project?.composition(id: sourceID)?.name ?? "Missing") {
                    ForEach((workspace.project?.compositionRegistry ?? []).filter { $0.id != workspace.activeComposition?.id }) { composition in
                        Button(composition.name) { workspace.setNestedComposition(composition.id) }
                    }
                }
                .buttonStyle(.bordered)
                HStack {
                    Text("Source Start")
                        .font(.caption)
                    TextField(
                        "Seconds",
                        value: Binding(
                            get: { sourceStart.seconds },
                            set: { workspace.setNestedSourceStart(seconds: $0) }
                        ),
                        format: .number.precision(.fractionLength(0...3))
                    )
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                }
            }
        }
    }

    private func modelOnlyControls(_ layer: ProjectLayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Model only · no Phase 6 output effect", systemImage: "info.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            switch layer.source {
            case .camera(let settings):
                slider("Focal Length", value: Binding(
                    get: { settings.focalLengthMillimeters },
                    set: { workspace.setCameraFocalLength($0) }
                ), range: 10...200)
            case .light(let settings):
                slider("Intensity", value: Binding(
                    get: { settings.intensity },
                    set: { workspace.setLightIntensity($0) }
                ), range: 0...10)
            default:
                Text("This layer persists and participates in ordering and Undo/Redo, but produces no pixels.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
    }

    private func boolBinding(
        _ keyPath: KeyPath<ProjectLayer, Bool>,
        _ setter: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { workspace.selectedLayer?[keyPath: keyPath] ?? false },
            set: setter
        )
    }

    private func transformBinding(
        _ keyPath: WritableKeyPath<LayerTransform, Double>,
        key: String
    ) -> Binding<Double> {
        Binding(
            get: { workspace.selectedLayer?.transform[keyPath: keyPath] ?? 0 },
            set: { value in
                guard var transform = workspace.selectedLayer?.transform else { return }
                transform[keyPath: keyPath] = value
                workspace.setLayerTransform(transform, mergeKey: key)
            }
        )
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            Slider(value: value, in: range)
                .tint(AfterEffectsTheme.accent)
        }
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            TextField(label, value: value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func exposure(_ layer: ProjectLayer) -> Double {
        for case .exposure(let value) in layer.operations { return value }
        return 0
    }

    private func saturation(_ layer: ProjectLayer) -> Double {
        for case .saturation(let value) in layer.operations { return value }
        return 1
    }

    private func inverted(_ layer: ProjectLayer) -> Bool {
        for case .invert(let value) in layer.operations { return value }
        return false
    }

    private func sync() {
        guard let layer = workspace.selectedLayer else { return }
        name = layer.name
        startSeconds = layer.timing.startTime.seconds
        inSeconds = layer.timing.inPoint.seconds
        outSeconds = layer.timing.outPoint.seconds
    }
}
