import SwiftUI

struct PulseAnimation: ViewModifier {
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.8 : 1.0)
            .animation(
                isAnimating ? 
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                    .default,
                value: isAnimating
            )
    }
}

extension View {
    func pulseAnimation(isAnimating: Bool) -> some View {
        modifier(PulseAnimation(isAnimating: isAnimating))
    }
}
