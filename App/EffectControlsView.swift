import SwiftUI
import VertexCore
import VertexProject

struct EffectControlsView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFECT CONTROLS")
                    .font(.caption.bold())
                    .foregroundStyle(AfterEffectsTheme.accent)
                Spacer()
                if let layer = workspace.selectedLayer {
                    Menu {
                        ForEach(ProjectEffectType.allCases, id: \.self) { type in
                            Button(type.displayName) { add(type, to: layer.id) }
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(!layer.isPhase9EffectEligible)
                }
            }
            .buttonStyle(.bordered)

            if let layer = workspace.selectedLayer {
                if layer.effects.isEmpty {
                    Text(layer.isPhase9EffectEligible ? "Add an AI effect to this layer." : "AI pixel effects require a media layer.")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(layer.effects.enumerated()), id: \.element.id) { index, effect in
                        AIEffectControlsView(layer: layer, effect: effect, index: index, errorMessage: $errorMessage)
                            .environmentObject(workspace)
                    }
                }
            } else {
                Text("Select a layer to inspect its effects.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
    }

    private func add(_ type: ProjectEffectType, to layerID: VertexID) {
        do {
            try workspace.addEffect(type, to: layerID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension ProjectLayer {
    var isPhase9EffectEligible: Bool {
        if case .media = source { return true }
        return false
    }
}

private extension ProjectEffectType {
    var displayName: String {
        switch self {
        case .depthMap: "Depth Map"
        case .cutout: "Cutout"
        case .upscale: "Upscale"
        case .restore: "Restore"
        }
    }
}
