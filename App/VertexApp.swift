import SwiftUI
import VertexCore

@main
struct AfterEffectsApp: App {
    @State private var isReady = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isReady {
                    RootView()
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .background(AfterEffectsTheme.background.ignoresSafeArea())
            .task {
                guard !isReady else { return }

                let startupMetadataIsValid = StartupReadinessPolicy.shouldEnterApp(
                    architectureContracts: CoreArchitectureCatalog.contracts,
                    milestone: MilestoneCatalog.current
                )
                let splashDelay: UInt64 = startupMetadataIsValid ? 1_250_000_000 : 0

                try? await Task.sleep(nanoseconds: splashDelay)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.32)) {
                    isReady = true
                }
            }
        }
    }
}
