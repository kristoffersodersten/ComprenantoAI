import SwiftUI
import CoreHaptics

class HapticSystem {
    static let shared = HapticSystem()
    
    private var engine: CHHapticEngine?
    
    init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine creation failed: \(error)")
        }
    }
    
    func playFeedback(_ type: FeedbackType) {
        switch type {
        case .success:
            playHapticPattern(intensity: 0.6, sharpness: 0.7)
        case .error:
            playHapticPattern(intensity: 0.8, sharpness: 0.4)
        case .warning:
            playHapticPattern(intensity: 0.5, sharpness: 0.5)
        case .selection:
            playHapticPattern(intensity: 0.3, sharpness: 0.8)
        }
    }
    
    private func playHapticPattern(intensity: Float, sharpness: Float) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }
        
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParameter, sharpnessParameter],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    enum FeedbackType {
        case success, error, warning, selection
    }
}
