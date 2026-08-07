import SwiftUI
import VertexProject

struct ExactFrameNavigatorView: View {
    @ObservedObject var preview: CompositionPreviewController
    let composition: ProjectComposition

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { preview.setFrameIndex(0, composition: composition) } label: {
                    Image(systemName: "backward.end.fill")
                }
                Button { preview.step(by: -1, composition: composition) } label: {
                    Image(systemName: "backward.frame.fill")
                }
                TextField("Frame", value: frameBinding, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                    .multilineTextAlignment(.center)
                Button { preview.step(by: 1, composition: composition) } label: {
                    Image(systemName: "forward.frame.fill")
                }
                Button {
                    preview.setFrameIndex(preview.lastFrameIndex(for: composition), composition: composition)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
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

            HStack {
                Text("Frame \(preview.frameIndex)")
                Spacer()
                Text("Last \(preview.lastFrameIndex(for: composition))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
    }

    private var frameBinding: Binding<Int64> {
        Binding(
            get: { preview.frameIndex },
            set: { preview.setFrameIndex($0, composition: composition) }
        )
    }
}
