import SwiftUI

enum PremiumDesignSystem {
    // ... (tidigare kod)

    enum Layout {
        static let cornerRadius: CGFloat = 16 // Konsekvent hörnradie för alla element
    }

    // ... (tidigare kod)
}

// Uppdaterad ViewModifier för konsekvent rundade hörn
struct PremiumCornerRadius: ViewModifier {
    func body(content: Content) -> some View {
        content
            .cornerRadius(PremiumDesignSystem.Layout.cornerRadius)
    }
}

extension View {
    func premiumCornerRadius() -> some View {
        self.modifier(PremiumCornerRadius())
    }
}
