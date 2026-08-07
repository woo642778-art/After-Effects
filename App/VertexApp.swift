import SwiftUI

@main
struct AfterEffectsApp: App {
    @State private var startupState: AppStartupState = .splash

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch startupState {
                case .splash:
                    Vertex2SplashView()
                        .transition(.opacity)

                case .workspace:
                    RootView()
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))

                case .fatalConfigurationError(let message):
                    StartupFatalErrorView(message: message)
                        .transition(.opacity)
                }
            }
            .background(AfterEffectsTheme.background.ignoresSafeArea())
            .task {
                await finishStartupIfNeeded()
            }
        }
    }

    @MainActor
    private func finishStartupIfNeeded() async {
        guard startupState == .splash else { return }

        // Splash is presentation only. Cancellation, AI/model availability, Metal,
        // project inspection, and milestone numbers must never leave the app here.
        try? await Task.sleep(for: .milliseconds(850))

        let hasRequiredUI = Bundle.main.url(forResource: "Assets", withExtension: "car") != nil
        let terminal = AppStartupPolicy.terminalState(bundleUIAvailable: hasRequiredUI)
        withAnimation(.easeInOut(duration: 0.28)) {
            startupState = terminal
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
