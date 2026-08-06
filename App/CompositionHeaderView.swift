import SwiftUI
import VertexCore
import VertexProject

struct CompositionHeaderView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @State private var name = ""
    @State private var width = 1080
    @State private var height = 1080
    @State private var duration = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("COMPOSITION")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AfterEffectsTheme.accent)
                        .tracking(0.8)
                    Text("Exact frames · schema 2 layers")
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                Spacer()
                compositionMenu
            }

            HStack(spacing: 8) {
                TextField("Composition name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { workspace.renameActiveComposition(name) }
                Button("Rename") { workspace.renameActiveComposition(name) }
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button { workspace.createComposition() } label: {
                    Label("New", systemImage: "plus")
                }
                Button { workspace.duplicateActiveComposition() } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) { workspace.removeActiveComposition() } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(workspace.activeCompositionDeletionBlockReason != nil)
            }
            .buttonStyle(.bordered)
            .tint(AfterEffectsTheme.accent)

            if let reason = workspace.activeCompositionDeletionBlockReason {
                Label(reason, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                valueField("W", value: $width)
                valueField("H", value: $height)
                Button("Apply Size") {
                    workspace.setActiveCompositionDimensions(width: width, height: height)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("Duration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                TextField("Seconds", value: $duration, format: .number.precision(.fractionLength(0...3)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 110)
                Button("Apply") { workspace.setActiveCompositionDuration(seconds: duration) }
                    .buttonStyle(.bordered)
                Spacer()
                if let composition = workspace.activeComposition {
                    Text("\(composition.frameRate.seconds.formatted(.number.precision(.fractionLength(0...3)))) fps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
            }
        }
        .onAppear(perform: sync)
        .onChange(of: workspace.project?.activeCompositionID) { _, _ in sync() }
        .onChange(of: workspace.project?.revision) { _, _ in syncIfIdentityChanged() }
    }

    private var compositionMenu: some View {
        Menu {
            ForEach(workspace.project?.compositionRegistry ?? []) { composition in
                Button {
                    workspace.selectComposition(composition.id)
                } label: {
                    if composition.id == workspace.project?.activeCompositionID {
                        Label(composition.name, systemImage: "checkmark")
                    } else {
                        Text(composition.name)
                    }
                }
            }
        } label: {
            Label(workspace.activeComposition?.name ?? "No Composition", systemImage: "square.stack.3d.up")
        }
        .buttonStyle(.borderedProminent)
        .tint(AfterEffectsTheme.accent)
    }

    private func valueField(_ label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(AfterEffectsTheme.secondaryText)
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 90)
        }
    }

    private func sync() {
        guard let composition = workspace.activeComposition else { return }
        name = composition.name
        width = composition.width
        height = composition.height
        duration = composition.duration.seconds
    }

    private func syncIfIdentityChanged() {
        guard let composition = workspace.activeComposition else { return }
        if name != composition.name && !name.isEmpty { return }
        sync()
    }
}
