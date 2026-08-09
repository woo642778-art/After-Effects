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

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                parameterControls
                HStack {
                    Text(effect.type.isNativePixelEffect ? "Live · shared preview/export processor" : state.label)
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

                if !effect.type.isNativePixelEffect {
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
                Text(effect.type.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("fx")
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .onDisappear { bakeTask?.cancel() }
    }

    @ViewBuilder
    private var parameterControls: some View {
        ForEach(effect.parameters) { parameter in
            HStack(spacing: 8) {
                Text(parameter.id.replacingOccurrences(of: "temporalSmoothing", with: "Temporal Smooth").capitalized)
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
                    Slider(
                        value: Binding(get: { value }, set: { setParameter(parameter.id, .scalar($0)) }),
                        in: scalarRange(parameter.id)
                    )
                    Text(String(format: "%.2f", value))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 44)
                case .integer(let value):
                    Stepper("\(value)", value: Binding(
                        get: { value },
                        set: { setParameter(parameter.id, .integer($0)) }
                    ), in: 0...256)
                    .font(.caption)
                case .text(let value):
                    Picker(parameter.id, selection: Binding(
                        get: { value },
                        set: { setParameter(parameter.id, .text($0)) }
                    )) {
                        ForEach(textOptions(parameter.id, current: value), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private func scalarRange(_ id: String) -> ClosedRange<Double> {
        switch id {
        case UpscaleParameterID.scale: 1...4
        case GaussianBlurParameterID.radius: 0...200
        case SharpenParameterID.sharpness: 0...2
        case ExposureEffectParameterID.stops: -10...10
        case ColorControlsParameterID.brightness: -1...1
        case ColorControlsParameterID.contrast: 0...4
        case ColorControlsParameterID.saturation: 0...2
        case HueAdjustParameterID.degrees: -180...180
        default: 0...1
        }
    }

    private func textOptions(_ id: String, current: String) -> [String] {
        switch id {
        case DepthMapParameterID.model: return ["depth-anything-v2-small-f16"]
        case DepthMapParameterID.quality, CutoutParameterID.quality, UpscaleParameterID.quality, RestorationParameterID.quality:
            return ["preview", "balanced", "quality"]
        case DepthMapParameterID.output: return ["depth", "alpha"]
        case CutoutParameterID.mode: return ["personFast", "foregroundFast", "promptQuality"]
        case UpscaleParameterID.profile: return ["general", "animeGame"]
        default: return [current]
        }
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
        guard !effect.type.isNativePixelEffect else { return }
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
