import SwiftUI

struct Vertex2SplashView: View {
    @State private var isVisible = false

    var body: some View {
        ZStack {
            AfterEffectsTheme.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    AfterEffectsTheme.accent.opacity(0.16),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            Text("Vertex2")
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white)
                .scaleEffect(isVisible ? 1 : 0.92)
                .opacity(isVisible ? 1 : 0)
                .blur(radius: isVisible ? 0 : 4)
                .accessibilityAddTraits(.isHeader)
        }
        .task {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                isVisible = true
            }
        }
    }
}
