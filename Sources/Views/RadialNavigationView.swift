import SwiftUI
import os.log
import CoreHaptics // Import CoreHaptics for advanced haptics

// DesignSystem (Consider moving this to a separate file)
enum DesignSystem {
    enum Animations {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    }
    enum Haptics {
        static let engine = try? CHHapticEngine()
        static func lightTap() {
            engine?.start()
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                let player = try CHHapticPlayer(pattern: pattern)
                try player.start(atTime: 0)
            } catch {
                print("Error playing haptic: \(error)")
            }
        }
        static func distinctTap() {
            engine?.start()
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try CHHapticPlayer(pattern: pattern)
                try player.start(atTime: 0)
            } catch {
                print("Error playing haptic: \(error)")
            }
        }
        static func moduleClose() {
            engine?.start()
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try CHHapticPlayer(pattern: pattern)
                try player.start(atTime: 0)
            } catch {
                print("Error playing haptic: \(error)")
            }
        }
    }
    enum Dimensions {
        static let fanRadius: CGFloat = 140
        static let iconSize: CGFloat = 48
        static let navHubSize: CGFloat = 64
        static let shadowRadius: CGFloat = 8
    }
    enum Colors {
        enum Gradient {
            static let gold = LinearGradient(gradient: Gradient(colors: [.yellow, .orange]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

class NavigationHubViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var selectedModule: AppModule?
    @Published var activeModule: AppModule?
    @Published var isModuleActive = false
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "NavigationHubViewModel")

    func toggleExpansion() {
        withAnimation(DesignSystem.Animations.spring) {
            isExpanded.toggle()
        }
        if isExpanded {
            DesignSystem.Haptics.distinctTap()
        }
    }

    func selectModule(_ module: AppModule) {
        selectedModule = module
        isExpanded = false
        DesignSystem.Haptics.lightTap()
    }

    func activateModule() {
        guard let selectedModule = selectedModule else { return }
        activeModule = selectedModule
        isModuleActive = true
        DesignSystem.Haptics.distinctTap()
    }

    func deactivateModule() {
        isModuleActive = false
        DesignSystem.Haptics.moduleClose()
        withAnimation(DesignSystem.Animations.spring.delay(0.3)) {
            activeModule = nil
        }
    }
}

struct NavigationHub: View {
    @StateObject private var viewModel = NavigationHubViewModel()

    var body: some View {
        ZStack {
            if viewModel.isExpanded {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        viewModel.toggleExpansion()
                    }
            }
            ModuleFan(
                isExpanded: viewModel.isExpanded,
                selectedModule: viewModel.selectedModule,
                activeModule: viewModel.activeModule,
                onModuleSelect: viewModel.selectModule
            )
            HubButton(
                isExpanded: viewModel.isExpanded,
                isActive: viewModel.isModuleActive,
                onTap: viewModel.toggleExpansion,
                onLongPress: viewModel.activateModule
            )
        }
    }
}

// ... (ModuleFan, ModuleIcon, HubButton implementations) ...

enum AppModule: Int, CaseIterable, Identifiable {
    case transcription, translation, messaging, voiceCalls, videoCalls, textEditing

    var id: Int { rawValue }
    var index: Int { rawValue }
    var title: String {
        switch self {
        case .transcription: return "Transcribe"
        case .translation: return "Translate"
        case .messaging: return "Messages"
        case .voiceCalls: return "Call"
        case .videoCalls: return "Video"
        case .textEditing: return "Edit"
        }
    }
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .messaging: return "message.fill"
        case .voiceCalls: return "phone.fill"
        case .videoCalls: return "video.fill"
        case .textEditing: return "pencil"
        }
    }
    var accessibilityHint: String {
        switch self {
        case .transcription: return "Record and transcribe speech"
        case .translation: return "Translate text or speech"
        case .messaging: return "Send translated messages"
        case .voiceCalls: return "Make voice calls with translation"
        case .videoCalls: return "Make video calls with translation"
        case .textEditing: return "Edit and improve text"
        }
    }
}
