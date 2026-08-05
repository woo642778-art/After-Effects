import SwiftUI

struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            AfterEffectsTheme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: .black.opacity(0.32), radius: 28, y: 14)
                    .scaleEffect(isVisible ? 1 : 0.92)
                    .opacity(isVisible ? 1 : 0)

                VStack(spacing: 6) {
                    Text("After Effects")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Made by Maze")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AfterEffectsTheme.accent)
                }

                ProgressView()
                    .tint(AfterEffectsTheme.accent)
                    .controlSize(.regular)
                    .padding(.top, 8)

                Text("Preparing the core architecture")
                    .font(.caption)
                    .foregroundStyle(AfterEffectsTheme.secondaryText)
            }
            .padding(32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("After Effects, Made by Maze, loading")
    }
}
