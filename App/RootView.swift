import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("afterEffects.didPresentTelegramPromotion.v1")
    private var didPresentTelegramPromotion = false
    @State private var isTelegramPromotionPresented = false
    @StateObject private var projectWorkspace = ProjectWorkspaceViewModel()

    var body: some View {
        ZStack {
            AfterEffectsTheme.background.ignoresSafeArea()
            VertexEditorWorkspaceView()
        }
        .environmentObject(projectWorkspace)
        .preferredColorScheme(.dark)
        .onAppear(perform: presentTelegramPromotionIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { projectWorkspace.flushAutosave() }
        }
        .sheet(isPresented: $isTelegramPromotionPresented) {
            TelegramPromotionView()
        }
    }

    private func presentTelegramPromotionIfNeeded() {
        guard !didPresentTelegramPromotion else { return }
        didPresentTelegramPromotion = true
        DispatchQueue.main.async { isTelegramPromotionPresented = true }
    }
}
