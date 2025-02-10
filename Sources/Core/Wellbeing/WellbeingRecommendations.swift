import SwiftUI

final class WellbeingRecommendations {
    static let shared = WellbeingRecommendations()
    
    private let recommendationEngine = RecommendationEngine()
    private let notificationManager = WellbeingNotificationManager()
    private let interventionManager = InterventionManager()
    
    // MARK: - Recommendations
    
    func suggestBreak(based state: WellbeingState) async {
        // Generera personlig rekommendation
        let recommendation = await recommendationEngine.generateRecommendation(
            for: state
        )
        
        // Visa notifikation
        await notificationManager.showRecommendation(recommendation)
        
        // Spåra respons
        await trackRecommendationResponse(recommendation)
    }
    
    func suggest20202Rule() async {
        let recommendation = EyeHealthRecommendation(
            title: "Time for an Eye Break",
            message: "Look at something 20 feet away for 20 seconds every 20 minutes",
            type: .eyeStrain,
            duration: .seconds(20)
        )
        
        await notificationManager.showRecommendation(recommendation)
    }
    
    func suggestPostureCorrection() async {
        let recommendation = PostureRecommendation(
            title: "Posture Check",
            message: "Align your spine and adjust your screen height",
            type: .posture,
            correction: .screenHeight
        )
        
        await notificationManager.showRecommendation(recommendation)
    }
    
    func suggestStressBreak() async {
        let recommendation = StressRecommendation(
            title: "Mindful Moment",
            message: "Take a deep breath and reset",
            type: .stress,
            duration: .minutes(2)
        )
        
        await notificationManager.showRecommendation(recommendation)
    }
}

// MARK: - Recommendation Engine

final class RecommendationEngine {
    private let personalizer = RecommendationPersonalizer()
    private let contextAnalyzer = ContextAnalyzer()
    private let timingOptimizer = TimingOptimizer()
    
    func generateRecommendation(
        for state: WellbeingState
    ) async -> WellbeingRecommendation {
        // Analysera kontext
        let context = await contextAnalyzer.analyzeContext()
        
        // Generera basrekommendation
        let baseRecommendation = createBaseRecommendation(
            for: state,
            context: context
        )
        
        // Personalisera rekommendation
        return await personalizer.personalize(
            baseRecommendation,
            context: context
        )
    }
    
    private func createBaseRecommendation(
        for state: WellbeingState,
        context: UserContext
    ) -> WellbeingRecommendation {
        // Skapa lämplig rekommendation baserat på tillstånd
        if state.stressLevel > 0.8 {
            return createUrgentStressRecommendation()
        } else if state.eyeStrain > 0.7 {
            return createEyeStrainRecommendation()
        } else if state.poorPosture {
            return createPostureRecommendation()
        } else {
            return createGeneralWellbeingRecommendation()
        }
    }
}

// MARK: - Intervention Manager

final class InterventionManager {
    private let interventionScheduler = InterventionScheduler()
    private let effectivenessTracker = EffectivenessTracker()
    
    func scheduleIntervention(
        _ intervention: WellbeingIntervention
    ) async throws {
        // Validera intervention
        try validateIntervention(intervention)
        
        // Schemalägg intervention
        try await interventionScheduler.schedule(intervention)
        
        // Spåra effektivitet
        await effectivenessTracker.trackIntervention(intervention)
    }
    
    private func validateIntervention(
        _ intervention: WellbeingIntervention
    ) throws {
        // Validera timing
        guard intervention.timing.isValid else {
            throw WellbeingError.invalidTiming
        }
        
        // Validera duration
        guard intervention.duration.isValid else {
            throw WellbeingError.invalidDuration
        }
        
        // Validera typ
        guard intervention.type.isSupported else {
            throw WellbeingError.unsupportedIntervention
        }
    }
}

// MARK: - Supporting Types

struct WellbeingRecommendation {
    let title: String
    let message: String
    let type: RecommendationType
    let priority: RecommendationPriority
    let timing: RecommendationTiming
}

struct WellbeingIntervention {
    let type: InterventionType
    let timing: InterventionTiming
    let duration: InterventionDuration
    let intensity: InterventionIntensity
}

enum RecommendationType {
    case stress
    case eyeStrain
    case posture
    case fatigue
    case general
}

enum RecommendationPriority {
    case low
    case medium
    case high
    case urgent
}

struct RecommendationTiming {
    let preferredTime: Date
    let flexibility: TimeInterval
    let recurrence: RecurrencePattern
}

enum InterventionType {
    case break
    case exercise
    case meditation
    case stretch
    case hydration
}
