import SwiftUI

struct PremiumNavigationHub: View {
    @StateObject private var viewModel = PremiumNavigationViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background blur when expanded
            if viewModel.isExpanded {
                VisualEffectView(style: .systemThinMaterial)
                    .ignoresSafeArea()
                    .opacity(0.8)
                    .transition(.opacity)
                    .onTapGesture {
                        viewModel.collapse()
                    }
            }
            
            // Module fan
            ModuleFan(viewModel: viewModel)
            
            // Central hub button
            HubButton(viewModel: viewModel)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isExpanded)
    }
}

private struct ModuleFan: View {
    @ObservedObject var viewModel: PremiumNavigationViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            ForEach(AppModule.allCases) { module in
                ModuleButton(
                    module: module,
                    isSelected: viewModel.selectedModule == module,
                    position: calculatePosition(for: module),
                    action: { viewModel.selectModule(module) }
                )
                .offset(calculatePosition(for: module))
                .scaleEffect(viewModel.isExpanded ? 1 : 0.5)
                .opacity(viewModel.isExpanded ? 1 : 0)
            }
        }
    }
    
    private func calculatePosition(for module: AppModule) -> CGPoint {
        let angle = angleForModule(module)
        let radius: CGFloat = 140
        return CGPoint(
            x: cos(angle) * radius,
            y: sin(angle) * radius
        )
    }
    
    private func angleForModule(_ module: AppModule) -> Double {
        let totalModules = Double(AppModule.allCases.count)
        let index = Double(module.index)
        return .pi * (0.8 + (1.4 * index / (totalModules - 1)) - 0.7)
    }
}

private struct ModuleButton: View {
    let module: AppModule
    let isSelected: Bool
    let position: CGPoint
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PremiumIcon(
                    systemName: module.icon,
                    isActive: isSelected
                )
                
                Text(module.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .premiumButtonStyle(feedback: .mediumTap)
        .premiumGlow(isActive: isSelected)
    }
}

private struct HubButton: View {
    @ObservedObject var viewModel: PremiumNavigationViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: viewModel.toggleExpansion) {
            ZStack {
                Circle()
                    .fill(PremiumDesignSystem.Colors.gradient(for: colorScheme))
                    .frame(width: 56, height: 56)
                    .shadow(radius: viewModel.isExpanded ? 12 : 8)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 45 : 0))
            }
        }
        .premiumButtonStyle(feedback: .heavyTap)
        .premiumGlow(isActive: viewModel.isExpanded)
    }
}

@MainActor
class PremiumNavigationViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var selectedModule: AppModule?
    
    func toggleExpansion() {
        withAnimation {
            isExpanded.toggle()
        }
    }
    
    func collapse() {
        withAnimation {
            isExpanded = false
        }
    }
    
    func selectModule(_ module: AppModule) {
        withAnimation {
            selectedModule = module
            isExpanded = false
        }
    }
}

// Helper view for UIKit blur effect
struct VisualEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
