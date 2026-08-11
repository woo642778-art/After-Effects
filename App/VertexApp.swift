import SwiftUI

@main
struct AfterEffectsApp: App {
    @StateObject private var startup: VertexStartupCoordinator
    @StateObject private var focusMusic: FocusMusicPlayer

    init() {
        _startup = StateObject(
            wrappedValue: VertexStartupCoordinator(services: .live())
        )
        _focusMusic = StateObject(wrappedValue: FocusMusicPlayer())
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch startup.phase {
                case .ready:
                    RootView()
                        .transition(.opacity.combined(with: .scale(scale: 1.005)))

                case .fatal(let message):
                    StartupFatalErrorView(message: message)
                        .transition(.opacity)

                case .coldStart, .loading, .restoringSession:
                    Vertex2SplashView(phase: startup.phase)
                        .transition(.opacity)
                }
            }
            .environmentObject(focusMusic)
            .background(AfterEffectsTheme.background.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.18), value: startup.phase)
            .task {
                await startup.start()
            }
        }
    }
}

private struct StartupFatalErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38, weight: .semibold))
            Text("Vertex2 could not start")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}
