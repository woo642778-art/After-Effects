import SwiftUI

enum AfterEffectsTheme {
    static let background = Color(red: 3.0 / 255.0, green: 0, blue: 123.0 / 255.0)
    static let surface = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.14)
    static let accent = Color(red: 152.0 / 255.0, green: 152.0 / 255.0, blue: 254.0 / 255.0)
    static let secondaryText = Color.white.opacity(0.68)
}

extension View {
    func afterEffectsCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AfterEffectsTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AfterEffectsTheme.border, lineWidth: 1)
                    )
            )
    }
}
