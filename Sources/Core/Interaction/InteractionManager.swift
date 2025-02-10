import SwiftUI
import CoreHaptics

enum HapticEvent {
    case moduleTransition
    case success
    case error
    case warning
    case selection
    case impact
    case recording(RecordingEvent)
    case translation(TranslationEvent)
    
    enum RecordingEvent {
        case start
        case stop
        case levelTooLow
        case levelTooHigh
    }
    
    enum TranslationEvent {
        case start
        case complete
        case error
        case suggestion
    }
}

class InteractionManager {
    static let shared = InteractionManager()
    
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            engine?.resetHandler = { [weak self] in
                self?.setupHapticEngine()
            }
            
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    func provideFeedback(for event: HapticEvent) {
        switch event {
        case .moduleTransition:
            playTransitionHaptic()
        case .success:
            playSuccessHaptic()
        case .error:
            playErrorHaptic()
        case .warning:
            playWarningHaptic()
        case .selection:
            playSelectionHaptic()
        case .impact:
            playImpactHaptic()
        case .recording(let recordingEvent):
            handleRecordingEvent(recordingEvent)
        case .translation(let translationEvent):
            handleTranslationEvent(translationEvent)
        }
    }
    
    private func playTransitionHaptic() {
        guard let engine = engine else { return }
        
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play transition haptic: \(error)")
        }
    }
    
    private func playSuccessHaptic() {
        guard let engine = engine else { return }
        
        do {
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            let event1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity1, sharpness1],
                relativeTime: 0
            )
            
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
            let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity2, sharpness2],
                relativeTime: 0.1
            )
            
            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play success haptic: \(error)")
        }
    }
    
    private func handleRecordingEvent(_ event: HapticEvent.RecordingEvent) {
        switch event {
        case .start:
            startContinuousHaptic(intensity: 0.3, sharpness: 0.5)
        case .stop:
            stopContinuousHaptic()
        case .levelTooLow:
            playWarningHaptic()
        case .levelTooHigh:
            playErrorHaptic()
        }
    }
    
    private func handleTranslationEvent(_ event: HapticEvent.TranslationEvent) {
        switch event {
        case .start:
            playTransitionHaptic()
        case .complete:
            playSuccessHaptic()
        case .error:
            playErrorHaptic()
        case .suggestion:
            playSelectionHaptic()
        }
    }
    
    private func startContinuousHaptic(intensity: Float, sharpness: Float) {
        guard let engine = engine else { return }
        
        do {
            let intensityParameter = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: intensity
            )
            let sharpnessParameter = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: sharpness
            )
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: 0,
                duration: 100 // Long duration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: 0)
        } catch {
            print("Failed to start continuous haptic: \(error)")
        }
    }
    
    private func stopContinuousHaptic() {
        continuousPlayer?.stop(atTime: 0)
        continuousPlayer = nil
    }
    
    // Additional helper methods for other haptic patterns...
}
