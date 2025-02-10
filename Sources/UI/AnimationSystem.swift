import SwiftUI
import CoreHaptics

struct AnimationSystem {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    static let smooth = Animation.easeInOut(duration: 0.3)
    
    struct TransitionModifier: ViewModifier {
        let isActive: Bool
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isActive ? 1 : 0.9)
                .opacity(isActive ? 1 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
        }
    }
}

extension View {
    func smoothTransition(isActive: Bool) -> some View {
        modifier(AnimationSystem.TransitionModifier(isActive: isActive))
    }
}
