import SwiftUI
import Combine

struct NavigationHub: View {
    @StateObject private var viewModel = NavigationHubViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background overlay
            if viewModel.isExpanded {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        viewModel.toggleExpansion()
                    }
            }
            
            // Module fan
            ModuleFan(viewModel: viewModel)
            
            // Hub button
            HubButton(viewModel: viewModel)
        }
        .animation(DesignSystem.Animations.spring, value: viewModel.isExpanded)
    }
}

struct ModuleFan: View {
    @ObservedObject var viewModel: NavigationHubViewModel
    
    var body: some View {
        ZStack {
            ForEach(AppModule.allCases) { module in
                ModuleButton(
                    module: module,
                    isSelected: viewModel.selectedModule == module,
                    isActive: viewModel.activeModule == module,
                    position: position(for: module),
                    action: { viewModel.selectModule(module) }
                )
                .offset(position(for: module))
                .scaleEffect(viewModel.isExpanded ? 1 : 0.5)
                .opacity(viewModel.isExpanded ? 1 : 0)
            }
        }
    }
    
    private func position(for module: AppModule) -> CGPoint {
        let angle = angleForModule(module)
        let radius = DesignSystem.Layout.Navigation.fanRadius
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
    let isActive: Bool
    let position: CGPoint
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: module.icon)
                    .font(.system(size: DesignSystem.Layout.Navigation.moduleIconSize))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(module.title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: DesignSystem.Layout.Navigation.moduleIconSize * 2)
            .padding()
            .background(
                Circle()
                    .fill(isSelected ? DesignSystem.Colors.Gradient.primary : DesignSystem.Colors.secondaryBackground)
                    .shadow(radius: isSelected ? 8 : 4)
            )
        }
        .scaleEffect(isActive ? 1.1 : 1)
    }
}

struct HubButton: View {
    @ObservedObject var viewModel: NavigationHubViewModel
    
    var body: some View {
        Button(action: viewModel.toggleExpansion) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.Gradient.primary)
                    .frame(width: DesignSystem.Layout.Navigation.hubSize)
                    .shadow(radius: viewModel.isExpanded ? 12 : 8)
                
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 45 : 0))
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    viewModel.activateModule()
                }
        )
    }
}

@MainActor
class NavigationHubViewModel: ObservableObject {
    // Published state
    @Published private(set) var isExpanded = false
    @Published private(set) var selectedModule: AppModule?
    @Published private(set) var activeModule: AppModule?
    @Published private(set) var navigationState: NavigationState = .idle
    
    // Audio
    private let soundPlayer = SoundPlayer()
    
    // Publishers
    let moduleStatePublisher = PassthroughSubject<ModuleState, Never>()
    
    // MARK: - Types
    
    enum NavigationState {
        case idle
        case expanded
        case moduleSelected(AppModule)
        case moduleActive(AppModule)
    }
    
    struct ModuleState {
        let module: AppModule
        let isActive: Bool
        let timestamp: Date
    }
    
    // MARK: - Public Methods
    
    func toggleExpansion() {
        withAnimation(DesignSystem.Animations.spring) {
            isExpanded.toggle()
            navigationState = isExpanded ? .expanded : .idle
        }
        
        if isExpanded {
            soundPlayer.playSound("expand")
            DesignSystem.Haptics.playFeedback(.impact(.medium))
        } else {
            soundPlayer.playSound("collapse")
            DesignSystem.Haptics.playFeedback(.impact(.light))
        }
    }
    
    func selectModule(_ module: AppModule) {
        withAnimation(DesignSystem.Animations.spring) {
            selectedModule = module
            navigationState = .moduleSelected(module)
            isExpanded = false
        }
        
        soundPlayer.playSound("select")
        DesignSystem.Haptics.playFeedback(.selection)
        
        moduleStatePublisher.send(
            ModuleState(
                module: module,
                isActive: false,
                timestamp: Date()
            )
        )
    }
    
    func activateModule() {
        guard let module = selectedModule else { return }
        
        withAnimation(DesignSystem.Animations.spring) {
            activeModule = module
            navigationState = .moduleActive(module)
        }
        
        soundPlayer.playSound("activate")
        DesignSystem.Haptics.playFeedback(.notification(.success))
        
        moduleStatePublisher.send(
            ModuleState(
                module: module,
                isActive: true,
                timestamp: Date()
            )
        )
    }
    
    func deactivateModule() {
        withAnimation(DesignSystem.Animations.spring) {
            activeModule = nil
            navigationState = .idle
        }
        
        soundPlayer.playSound("deactivate")
        DesignSystem.Haptics.playFeedback(.notification(.warning))
    }
}

// MARK: - Sound Player

class SoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]
    
    init() {
        preloadSounds()
    }
    
    func playSound(_ name: String) {
        players[name]?.play()
    }
    
    private func preloadSounds() {
        let sounds = ["expand", "collapse", "select", "activate", "deactivate"]
        for sound in sounds {
            if let url = Bundle.main.url(forResource: sound, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    players[sound] = player
                } catch {
                    print("Failed to load sound: \(sound)")
                }
            }
        }
    }
}
