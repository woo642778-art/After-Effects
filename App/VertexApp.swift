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

                let architectureIsAvailable = !CoreArchitectureCatalog.contracts.isEmpty
                    && MilestoneCatalog.current.number == 5
                guard architectureIsAvailable else { return }

                try? await Task.sleep(nanoseconds: 1_250_000_000)
                withAnimation(.easeInOut(duration: 0.32)) {
                    isReady = true
                }
            }
        }
    }
}
