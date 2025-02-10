import SwiftUI
import Combine

final class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    @Published private(set) var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @Published private(set) var isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
    @Published private(set) var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default
            .publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String
    let traits: AccessibilityTraits
    let announcement: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
            .onChange(of: announcement) { newValue in
                if let announcement = newValue {
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
            }
    }
}

struct DynamicTypeModifier: ViewModifier {
    @ScaledMetric private var scale: CGFloat = 1
    
    func body(content: Content) -> some View {
        content.scaleEffect(scale)
    }
}

struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content.animation(.none)
            } else {
                content
            }
        }
    }
}

// MARK: - Accessibility Components

struct AccessibleButton: View {
    let action: () -> Void
    let label: String
    let hint: String
    let icon: String?
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(label)
            }
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}

struct AccessibleImage: View {
    let image: Image
    let label: String
    let decorative: Bool
    
    var body: some View {
        image
            .accessibilityLabel(decorative ? "" : label)
            .accessibilityHidden(decorative)
    }
}

// MARK: - View Extensions

extension View {
    func accessibleAction(
        label: String,
        hint: String,
        traits: AccessibilityTraits = [],
        announcement: String? = nil
    ) -> some View {
        modifier(AccessibilityModifier(
            label: label,
            hint: hint,
            traits: traits,
            announcement: announcement
        ))
    }
    
    func dynamicTypeScaling() -> some View {
        modifier(DynamicTypeModifier())
    }
    
    func reduceMotionAware() -> some View {
        modifier(ReduceMotionModifier())
    }
}

// MARK: - Accessibility Helpers

enum AccessibilityAnnouncement {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    static func announceScreen(_ screenName: String) {
        UIAccessibility.post(notification: .screenChanged, argument: screenName)
    }
}

struct AccessibilityIdentifier {
    static let transcriptionButton = "TranscriptionButton"
    static let translationButton = "TranslationButton"
    static let messageButton = "MessageButton"
    static let callButton = "CallButton"
    static let videoCallButton = "VideoCallButton"
    static let textEditorButton = "TextEditorButton"
}
