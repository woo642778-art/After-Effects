import SwiftUI
import VertexCore

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("afterEffects.didPresentTelegramPromotion.v1")
    private var didPresentTelegramPromotion = false

    @State private var isTelegramPromotionPresented = false
    @StateObject private var projectWorkspace = ProjectWorkspaceViewModel()

    private let milestone = MilestoneCatalog.current
    private let architectureContracts = CoreArchitectureCatalog.contracts

    var body: some View {
        ZStack {
            AfterEffectsTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statusCard
                    ProjectWorkspaceView()
                    MediaImportView()
                    architectureSection
                    sourcesSection
                    artifactCard
                    attribution
                }
                .padding(20)
                .padding(.bottom, 20)
            }
        }
        .environmentObject(projectWorkspace)
        .preferredColorScheme(.dark)
        .onAppear(perform: presentTelegramPromotionIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                projectWorkspace.flushAutosave()
            }
        }
        .sheet(isPresented: $isTelegramPromotionPresented) {
            TelegramPromotionView()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("After Effects")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Made by Maze")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.accent)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PHASE \(milestone.number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AfterEffectsTheme.accent)

                Spacer()

                Text(milestone.status.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AfterEffectsTheme.accent.opacity(0.18), in: Capsule())
            }

            Text(milestone.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            ForEach(milestone.deliverables, id: \.self) { deliverable in
                Label(deliverable, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .afterEffectsCard()
    }

    private var architectureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CORE CONTRACTS")

            ForEach(architectureContracts) { contract in
                VStack(alignment: .leading, spacing: 7) {
                    Text(contract.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(contract.guarantee)
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                .afterEffectsCard()
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SOURCE ADOPTION")

            ForEach(milestone.sourceAdoptions) { source in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(source.repository)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Text(source.license)
                            .font(.caption.monospaced())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                    }

                    Text(source.mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AfterEffectsTheme.accent)

                    Text(source.purpose)
                        .font(.caption)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                .afterEffectsCard()
            }
        }
    }

    private var artifactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unsigned IPA pipeline", systemImage: "shippingbox.fill")
                .font(.headline)
                .foregroundStyle(.white)

            Text(milestone.artifactPolicy)
                .font(.caption)
                .foregroundStyle(AfterEffectsTheme.secondaryText)
        }
        .afterEffectsCard()
    }

    private var attribution: some View {
        Text("After Effects · Made by Maze")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.48))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AfterEffectsTheme.accent)
            .tracking(0.8)
    }

    private func presentTelegramPromotionIfNeeded() {
        var gate = OneTimePresentationGate(hasPresented: didPresentTelegramPromotion)
        guard gate.consumePresentation() else { return }

        didPresentTelegramPromotion = gate.hasPresented
        DispatchQueue.main.async {
            isTelegramPromotionPresented = true
        }
    }
}
