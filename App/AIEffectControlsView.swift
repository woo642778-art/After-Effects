import SwiftUI
import VertexCore
import VertexProject

enum AIEffectPresentationState: Equatable {
    case ready
    case computing
    case cached
    case stale
    case failed(String)

    var usesSourcePixels: Bool {
        switch self {
        case .computing, .stale, .failed: true
        case .ready, .cached: false
        }
    }

    var label: String {
        switch self {
        case .ready: "Ready"
        case .computing: "Computing"
        case .cached: "Cached"
        case .stale: "Stale · showing source"
        case .failed(let message): "Failed · showing source: \(message)"
        }
    }
}

struct AIEffectControlsView: View {
    let layer: ProjectLayer
    let effect: ProjectEffect
    let index: Int
    @Binding var errorMessage: String?
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var isExpanded = true
    @State private var bakeTask: Task<Void, Never>?
    @State private var state: AIEffectPresentationState = .ready
    @State private var scalarDrafts: [String: Double] = [:]
    @State private var previewGates: [String: EffectPreviewUpdateGate] = [:]

    private var descriptor: ProjectEffectDescriptor { effect.type.descriptor }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                parameterControls
                HStack {
                    Text(effect.type.isNativePixelEffect ? "Live · adaptive preview / full-quality export" : state.label)
                        .font(.caption2.monospaced())
                        .foregroundStyle(effect.type.isNativePixelEffect ? AfterEffectsTheme.secondaryText : (state.usesSourcePixels ? .orange : AfterEffectsTheme.secondaryText))
                    Spacer()
                    Button(index == 0 ? "Top" : "↑") { move(to: max(0, index - 1)) }
                        .disabled(index == 0)
                    Button(index >= layer.effects.count - 1 ? "Bottom" : "↓") { move(to: min(layer.effects.count - 1, index + 1)) }
                        .disabled(index >= layer.effects.count - 1)
                    Button(role: .destructive) { remove() } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.bordered)

                if descriptor.executionMode == .aiBake {
                    HStack {
                        Button {
                            startBake()
                        } label: {
                            if case .computing = state {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Extract / Bake to Layer", systemImage: "square.stack.3d.up")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AfterEffectsTheme.accent)
                        .disabled(!effect.enabled || bakeTask != nil)

                        if bakeTask != nil {
                            Button("Cancel", role: .cancel) {
                                bakeTask?.cancel()
                                bakeTask = nil
                                state = .ready
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Toggle("", isOn: Binding(
                    get: { effect.enabled },
                    set: { setEnabled($0) }
                ))
                .labelsHidden()
                Text(descriptor.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("fx")
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .onDisappear {
            bakeTask?.cancel()
            commitAllScalarDrafts()
        }
    }

    @ViewBuilder
    private var parameterControls: some View {
        ForEach(effect.parameters) { parameter in
            let metadata = descriptor.parameter(id: parameter.id)
            HStack(spacing: 8) {
                Text(metadata?.displayName ?? parameter.id)
                    .font(.caption)
                    .frame(width: 112, alignment: .leading)
                switch parameter.value {
                case .boolean(let value):
                    Toggle("", isOn: Binding(
                        get: { value },
                        set: { setParameter(parameter.id, .boolean($0)) }
                    ))
                    .labelsHidden()
                case .scalar(let value):
                    let displayValue = scalarDrafts[parameter.id] ?? value
                    Slider(
                        value: Binding(
                            get: { scalarDrafts[parameter.id] ?? value },
                            set: { updateScalarDraft(parameter.id, value: $0) }
                        ),
                        in: metadata?.domain.scalarRange ?? 0...1,
                        onEditingChanged: { editing in
                            if !editing { commitScalarDraft(parameter.id) }
                        }
                    )
                    Text(String(format: "%.2f", displayValue))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 44)
                case .integer(let value):
                    Stepper("\(value)", value: Binding(
                        get: { value },
                        set: { setParameter(parameter.id, .integer($0)) }
                    ), in: metadata?.domain.integerRange ?? 0...256)
                    .font(.caption)
                case .text(let value):
                    Picker(metadata?.displayName ?? parameter.id, selection: Binding(
                        get: { value },
                        set: { setParameter(parameter.id, .text($0)) }
                    )) {
                        ForEach(metadata?.domain.textOptions ?? [value], id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private func updateScalarDraft(_ id: String, value: Double) {
        // The local draft changes on every touch sample so the slider itself remains responsive.
        // Project mutations (and therefore expensive preview renders) are intentionally coalesced.
        scalarDrafts[id] = value
        var gate = previewGates[id] ?? EffectPreviewUpdateGate(minimumInterval: interactivePreviewInterval)
        if gate.shouldCommit(at: ProcessInfo.processInfo.systemUptime) {
            setParameter(id, .scalar(value))
        }
        previewGates[id] = gate
    }

    private var interactivePreviewInterval: TimeInterval {
        // AI effects do not re-run full inference on every finger sample. Native spatial effects
        // are also deliberately capped below the color/control cadence because blur, morphology,
        // halftone, distortion, tile and composite chains can exceed an iPad frame budget on 4K media.
        guard effect.type.isNativePixelEffect else { return 1.0 / 6.0 }
        switch descriptor.category {
        case .blurAndSharpen, .stylize, .distort, .tile, .keying:
            return 1.0 / 8.0
        case .colorCorrection, .channel:
            return 1.0 / 15.0
        case .ai:
            return 1.0 / 6.0
        }
    }

    private func commitScalarDraft(_ id: String) {
        guard let value = scalarDrafts[id] else { return }
        var gate = previewGates[id] ?? EffectPreviewUpdateGate(minimumInterval: interactivePreviewInterval)
        _ = gate.shouldCommitFinal(at: ProcessInfo.processInfo.systemUptime)
        previewGates[id] = gate
        setParameter(id, .scalar(value))
        scalarDrafts[id] = nil
    }

    private func commitAllScalarDrafts() {
        for id in Array(scalarDrafts.keys) { commitScalarDraft(id) }
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            try workspace.setEffectEnabled(layerID: layer.id, effectID: effect.id, enabled: enabled)
            state = enabled ? .ready : .stale
            errorMessage = nil
        } catch {
            state = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func setParameter(_ id: String, _ value: ProjectEffectParameterValue) {
        do {
            try workspace.setEffectParameter(layerID: layer.id, effectID: effect.id, parameterID: id, value: value)
            state = effect.type.isNativePixelEffect ? .ready : .stale
            errorMessage = nil
        } catch {
            state = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func move(to destination: Int) {
        do {
            try workspace.moveEffect(layerID: layer.id, effectID: effect.id, to: destination)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func remove() {
        do {
            try workspace.removeEffect(layerID: layer.id, effectID: effect.id)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func startBake() {
        guard descriptor.executionMode == .aiBake else { return }
        state = .computing
        let task = Task { @MainActor in
            do {
                try await workspace.bakeEffect(layerID: layer.id, effectID: effect.id)
                guard !Task.isCancelled else { return }
                state = .cached
                errorMessage = nil
            } catch is CancellationError {
                state = .ready
            } catch {
                state = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
            bakeTask = nil
        }
        bakeTask = task
    }
}
