import SwiftUI

enum AfterEffectsTheme {
    static let background = Color(red: 0.055, green: 0.058, blue: 0.067)
    static let panel = Color(red: 0.078, green: 0.082, blue: 0.094)
    static let elevatedPanel = Color(red: 0.100, green: 0.104, blue: 0.118)
    static let surface = Color.white.opacity(0.055)
    static let border = Color.white.opacity(0.10)
    static let strongBorder = Color.white.opacity(0.17)
    static let accent = Color(red: 0.50, green: 0.57, blue: 1.0)
    static let selection = accent.opacity(0.20)
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.60)
    static let tertiaryText = Color.white.opacity(0.40)
    static let viewerBackground = Color.black
}

extension View {
    func afterEffectsCard() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AfterEffectsTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AfterEffectsTheme.border, lineWidth: 1)
                    )
            )
    }
}
