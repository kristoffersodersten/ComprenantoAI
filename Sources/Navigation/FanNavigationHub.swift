import SwiftUI
import CoreHaptics

struct FanNavigationHub: View {
    @StateObject private var viewModel = FanNavigationViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background overlay when expanded
            if viewModel.isExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
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

struct ModuleFan: View {
    @ObservedObject var viewModel: FanNavigationViewModel
    
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

struct ModuleButton: View {
    let module: AppModule
    let isSelected: Bool
    let position: CGPoint
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: module.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(module.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(isSelected ? 
                        DesignSystem.Colors.Gradient.primary :
                        DesignSystem.Colors.secondaryBackground
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isSelected ? 8 : 4
                    )
            )
        }
        .accessibilityLabel("\(module.title) Module")
        .accessibilityHint(module.accessibilityHint)
    }
}

struct HubButton: View {
    @ObservedObject var viewModel: FanNavigationViewModel
    
    var body: some View {
        Button(action: viewModel.toggleExpansion) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.Gradient.primary)
                    .frame(width: 56, height: 56)
                    .shadow(radius: viewModel.isExpanded ? 12 : 8)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 45 : 0))
            }
        }
        .accessibilityLabel(viewModel.isExpanded ? "Close Menu" : "Open Menu")
    }
}

enum AppModule: Int, CaseIterable, Identifiable {
    case transcription
    case translation
    case messaging
    case calls
    case video
    case editor
    
    var id: Int { rawValue }
    var index: Int { rawValue }
    
    var title: String {
        switch self {
        case .transcription: return "Transcribe"
        case .translation: return "Translate"
        case .messaging: return "Messages"
        case .calls: return "Calls"
        case .video: return "Video"
        case .editor: return "Editor"
        }
    }
    
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .messaging: return "message.fill"
        case .calls: return "phone.fill"
        case .video: return "video.fill"
        case .editor: return "pencil"
        }
    }
    
    var accessibilityHint: String {
        switch self {
        case .transcription: return "Transcribe speech to text"
        case .translation: return "Translate between languages"
        case .messaging: return "Send and receive messages"
        case .calls: return "Make voice calls"
        case .video: return "Make video calls"
        case .editor: return "Edit and format text"
        }
    }
}

@MainActor
class FanNavigationViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var selectedModule: AppModule?
    
    private var hapticEngine: CHHapticEngine?
    
    init() {
        setupHaptics()
    }
    
    func toggleExpansion() {
        withAnimation {
            isExpanded.toggle()
        }
        playHapticFeedback(isExpanded ? .expansion : .collapse)
    }
    
    func collapse() {
        withAnimation {
            isExpanded = false
        }
        playHapticFeedback(.collapse)
    }
    
    func selectModule(_ module: AppModule) {
        withAnimation {
            selectedModule = module
            isExpanded = false
        }
        playHapticFeedback(.selection)
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine creation failed: \(error)")
        }
    }
    
    private func playHapticFeedback(_ type: HapticType) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        let intensity: Float
        let sharpness: Float
        
        switch type {
        case .expansion:
            intensity = 0.6
            sharpness = 0.7
        case .collapse:
            intensity = 0.5
            sharpness = 0.5
        case .selection:
            intensity = 0.8
            sharpness = 0.9
        }
        
        do {
            let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    private enum HapticType {
        case expansion
        case collapse
        case selection
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        
        FanNavigationHub()
    }
}
