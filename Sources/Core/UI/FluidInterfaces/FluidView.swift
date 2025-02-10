import SwiftUI

struct FluidView<Content: View>: View {
    let content: Content
    @StateObject private var fluidController = FluidViewController()
    @Environment(\.fluidTransition) private var transition
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(FluidViewModifier(controller: fluidController))
            .onChange(of: transition) { newTransition in
                if let newTransition = newTransition {
                    fluidController.applyTransition(newTransition)
                }
            }
    }
}

final class FluidViewController: ObservableObject {
    @Published private(set) var currentState: FluidState = .identity
    private let fluidEngine = FluidEngine()
    
    func applyTransition(_ transition: FluidTransition) {
        Task {
            do {
                try await fluidEngine.apply(transition, to: &currentState)
            } catch {
                print("Failed to apply transition: \(error)")
            }
        }
    }
}

struct FluidViewModifier: ViewModifier {
    @ObservedObject var controller: FluidViewController
    
    func body(content: Content) -> some View {
        content
            .modifier(FluidGeometryEffect(state: controller.currentState))
            .animation(.fluidSpring(), value: controller.currentState)
    }
}

struct FluidGeometryEffect: GeometryEffect {
    let state: FluidState
    
    var animatableData: FluidState.AnimatableData {
        get { state.animatableData }
        set { /* Update state if needed */ }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        state.transform(for: size)
    }
}

extension Animation {
    static func fluidSpring(
        response: Double = 0.4,
        dampingFraction: Double = 0.825,
        blendDuration: Double = 0.3
    ) -> Animation {
        .spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }
}
