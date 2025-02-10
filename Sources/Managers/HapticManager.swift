import CoreHaptics
import os.log

enum HapticManagerError: Error {
    case hapticEngineCreationFailed(Error)
    case hapticFeedbackFailed(Error)
}

class HapticManager {
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "HapticManager")
    private var engine: CHHapticEngine?

    enum HapticAction {
        case important, selection, success, warning
    }

    init() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            log.error("Haptic engine creation failed: \(error)")
            engine = nil
            // Handle error appropriately (e.g., disable haptics)
        }
    }

    func performHapticFeedback(for action: HapticAction) {
        guard engine != nil else { return }
        do {
            switch action {
            case .important:
                try playHapticFeedback(intensity: 0.8, sharpness: 0.9)
            case .selection:
                try playHapticFeedback(intensity: 0.3, sharpness: 0.5)
            case .success:
                try playHapticFeedback(intensity: 0.6, sharpness: 0.7)
            case .warning:
                try playHapticFeedback(intensity: 0.7, sharpness: 0.8)
            }
        } catch {
            log.error("Haptic feedback failed: \(error)")
        }
    }

    private func playHapticFeedback(intensity: Double, sharpness: Double) throws {
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParameter, sharpnessParameter],
            relativeTime: 0
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        if let player = try engine?.makePlayer(with: pattern) {
            try player.start(atTime: 0)
        }
    }
}
