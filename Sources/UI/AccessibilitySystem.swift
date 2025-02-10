import SwiftUI

struct AccessibilitySystem: ViewModifier {
    let label: String
    let hint: String
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
            .accessibilityElement(children: .combine)
    }
}

extension View {
    func enhancedAccessibility(
        label: String,
        hint: String,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(AccessibilitySystem(label: label, hint: hint, traits: traits))
    }
}
