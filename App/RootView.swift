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
            if projectWorkspace.project == nil {
                VertexHomeView()
                    .transition(.opacity)
            } else if projectWorkspace.activeComposition == nil {
                VertexEmptyProjectView()
                    .transition(.opacity)
            } else {
                VertexEditorWorkspaceView()
                    .transition(.opacity)
            }
        }
        .environmentObject(projectWorkspace)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.16), value: projectWorkspace.project?.projectID)
        .animation(.easeInOut(duration: 0.16), value: projectWorkspace.project?.activeCompositionID)
        .onChange(of: projectWorkspace.project?.projectID) { _, projectID in
            if projectID != nil {
                presentTelegramPromotionIfNeeded()
            }
        }
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
