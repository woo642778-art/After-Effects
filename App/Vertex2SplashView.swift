import SwiftUI

struct Vertex2SplashView: View {
    let phase: VertexStartupPhase
    @State private var isVisible = false

    var body: some View {
        ZStack {
            AfterEffectsTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.96)

                Text("Vertex Studio")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(.white)
                    .padding(.top, 17)

                Text("Professional motion graphics and compositing")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .padding(.top, 5)

                Spacer()

                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AfterEffectsTheme.secondaryText)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .lineLimit(1)
                }
                .padding(.bottom, 34)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
        .task {
            withAnimation(.easeOut(duration: 0.22)) {
                isVisible = true
            }
        }
    }

    private var statusText: String {
        switch phase {
        case .coldStart:
            "Initializing application..."
        case .loading(.projectPersistence):
            "Loading project services..."
        case .loading(.renderer):
            "Initializing Metal renderer..."
        case .loading(.effects):
            "Loading effects..."
        case .loading(.aiModels):
            "Loading AI models..."
        case .loading(.workspace), .restoringSession:
            "Restoring workspace..."
        case .ready:
            "Ready"
        case .fatal:
            "Startup failed"
        }
    }
}
