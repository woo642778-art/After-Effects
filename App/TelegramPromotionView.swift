import SwiftUI

struct TelegramPromotionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let telegramURL = URL(string: "https://t.me/aemotionios")!

    var body: some View {
        ZStack {
            AfterEffectsTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 8) {
                    Text("Join AE Motion")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Join the Telegram channel for development updates, test builds, and project news.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AfterEffectsTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button {
                        openURL(telegramURL)
                        dismiss()
                    } label: {
                        Label("Open Telegram", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AfterEffectsTheme.background)
                    .background(AfterEffectsTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button("Continue without joining") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                }

                Text("Made by Maze")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AfterEffectsTheme.accent)
            }
            .padding(28)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
