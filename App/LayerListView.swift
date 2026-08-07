import SwiftUI
import VertexCore
import VertexProject

struct LayerListView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    let frameIndex: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LAYERS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.accent)
                    .tracking(0.8)
                Spacer()
                addMenu
            }

            if workspace.orderedLayers.isEmpty {
                Text("Import media or add a layer. The top row is the highest Z-order.")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(workspace.orderedLayers.enumerated()), id: \.element.id) { index, layer in
                    layerRow(layer, index: index)
                }
            }

            HStack(spacing: 8) {
                Button { workspace.duplicateSelectedLayer() } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .disabled(workspace.selectedLayer == nil)
                Button(role: .destructive) { workspace.removeSelectedLayer() } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(workspace.selectedLayer == nil)
            }
            .buttonStyle(.bordered)
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Selected Media") { workspace.addSelectedMediaLayer() }
                .disabled(workspace.selectedMedia == nil)
            Button("Adjustment Layer") { workspace.addAdjustmentLayer() }
            Button("Null") { workspace.addNullLayer() }
            Button("Guide") { workspace.addGuideLayer() }
            Button("Camera · Model only") { workspace.addCameraLayer() }
            Button("Light · Model only") { workspace.addLightLayer() }
            Menu("Nested Composition") {
                ForEach((workspace.project?.compositionRegistry ?? []).filter { $0.id != workspace.activeComposition?.id }) { composition in
                    Button(composition.name) {
                        workspace.addNestedCompositionLayer(sourceCompositionID: composition.id)
                    }
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .tint(AfterEffectsTheme.accent)
        .disabled(workspace.activeComposition == nil)
    }

    private func layerRow(_ layer: ProjectLayer, index: Int) -> some View {
        let selected = workspace.project?.selectedLayerID == layer.id
        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    workspace.selectLayer(layer.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sourceIcon(layer.source))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layer.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Text(sourceName(layer.source))
                                Text(layer.blendMode.rawValue.uppercased())
                                if !isActive(layer) { Text("OUT") }
                                if isMissing(layer) { Text("MISSING") }
                                if layer.source.isModelOnly { Text("MODEL ONLY") }
                            }
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(isMissing(layer) ? .orange : AfterEffectsTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    workspace.selectLayer(layer.id)
                    workspace.setLayerEnabled(!layer.enabled)
                } label: {
                    Image(systemName: layer.enabled ? "eye.fill" : "eye.slash")
                }
                Button {
                    workspace.selectLayer(layer.id)
                    workspace.setLayerLocked(!layer.locked)
                } label: {
                    Image(systemName: layer.locked ? "lock.fill" : "lock.open")
                }
                Button {
                    workspace.selectLayer(layer.id)
                    workspace.setLayerSolo(!layer.solo)
                } label: {
                    Text("S")
                        .font(.caption.monospaced().weight(.black))
                }
            }

            HStack {
                Button {
                    workspace.moveLayer(layer.id, to: index - 1)
                } label: { Image(systemName: "arrow.up") }
                .disabled(index == 0 || layer.locked)
                Button {
                    workspace.moveLayer(layer.id, to: index + 1)
                } label: { Image(systemName: "arrow.down") }
                .disabled(index == workspace.orderedLayers.count - 1 || layer.locked)
                Spacer()
                Text("Z \(index)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            .buttonStyle(.borderless)
        }
        .foregroundStyle(selected ? Color.white : AfterEffectsTheme.secondaryText)
        .padding(9)
        .background(
            selected ? AfterEffectsTheme.accent.opacity(0.18) : Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func isActive(_ layer: ProjectLayer) -> Bool {
        guard layer.enabled, let composition = workspace.activeComposition else { return false }
        let seconds = Double(frameIndex) / max(composition.frameRate.seconds, 0.000001)
        guard let time = workspace.exactTime(seconds: seconds, frameRate: composition.frameRate) else { return false }
        return layer.timing.inPoint <= time && time < layer.timing.outPoint
    }

    private func isMissing(_ layer: ProjectLayer) -> Bool {
        if case .media(let mediaID, _) = layer.source {
            return workspace.missingMediaIDs.contains(mediaID)
        }
        return false
    }

    private func sourceName(_ source: LayerSource) -> String {
        switch source {
        case .media: "MEDIA"
        case .adjustment: "ADJUSTMENT"
        case .null: "NULL"
        case .guide: "GUIDE"
        case .camera: "CAMERA"
        case .light: "LIGHT"
        case .composition: "NESTED"
        }
    }

    private func sourceIcon(_ source: LayerSource) -> String {
        switch source {
        case .media: "film"
        case .adjustment: "slider.horizontal.3"
        case .null: "circle.dashed"
        case .guide: "ruler"
        case .camera: "camera"
        case .light: "lightbulb"
        case .composition: "square.stack.3d.up"
        }
    }
}
