import SwiftUI
import os.log

enum AnimationManagerError: Error {
    case animationError(String)
}

struct ShimmerModifier: ViewModifier {
    var color: Color
    var duration: Double
    var intensity: Double
    var baseAnimation: Animation

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.4 * intensity),
                        color.opacity(0.1 * intensity),
                        color.opacity(0.4 * intensity)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                    .mask(content)
                    .rotationEffect(.degrees(30))
                    .offset(x: phase * 10, y: phase * 10)
                    .animation(baseAnimation.repeatForever(autoreverses: false).speed(1 / duration), value: phase)
            )
            .onAppear {
                phase = 1
            }
    }
}

class AnimationManager {
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "AnimationManager")

    static func applyTiltEffect(
        to view: AnyView,
        angle: Angle = .degrees(10),
        duration: Double = 0.5,
        animation: Animation = .easeInOut
    ) -> some View {
        view
            .rotation3DEffect(angle, axis: (x: 1, y: 0, z: 0))
            .animation(animation, value: angle)
    }

    static func shimmerEffect(
        color: Color = .white,
        duration: Double = 2,
        intensity: Double = 0.5,
        baseAnimation: Animation = .linear
    ) -> some ViewModifier {
        ShimmerModifier(color: color, duration: duration, intensity: intensity, baseAnimation: baseAnimation)
    }
}
