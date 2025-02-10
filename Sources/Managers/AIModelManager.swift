import CoreML
import NaturalLanguage
import Foundation
import os.log

enum AIModelError: Error {
    case modelNotFound
    case modelLoadFailed(Error)
    case predictionFailed(Error)
    case invalidInput
}

class AIModelManager {
    static let shared = AIModelManager()
    private let log = Logger(subsystem: "com.comprenanto", category: "AIModelManager")
    
    // Language detection model
    private var languageDetector: NLLanguageRecognizer
    
    // Speech recognition confidence threshold
    private let confidenceThreshold: Float = 0.6
    
    private init() {
        languageDetector = NLLanguageRecognizer()
    }
    
    /// Detects the language of the given text
    func detectLanguage(from text: String) -> String? {
        guard !text.isEmpty else {
            log.error("Empty text provided for language detection")
            return nil
        }
        
        languageDetector.reset()
        languageDetector.processString(text)
        
        if let language = languageDetector.dominantLanguage {
            let confidence = languageDetector.languageHypotheses(withMaximum: 1)[language] ?? 0
            
            log.info("Detected language: \(language.rawValue) with confidence: \(confidence)")
            return language.rawValue
        }
        
        return nil
    }
    
    /// Gets language probabilities for the given text
    func getLanguageProbabilities(for text: String) -> [String: Double] {
        guard !text.isEmpty else {
            log.error("Empty text provided for language probabilities")
            return [:]
        }
        
        languageDetector.reset()
        languageDetector.processString(text)
        
        let hypotheses = languageDetector.languageHypotheses(withMaximum: 3)
        return hypotheses.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
    }
    
    /// Validates speech recognition confidence
    func validateTranscription(_ transcription: String, confidence: Float) -> Bool {
        guard !transcription.isEmpty else {
            log.error("Empty transcription provided for validation")
            return false
        }
        
        // Check confidence threshold
        guard confidence >= confidenceThreshold else {
            log.info("Transcription confidence below threshold: \(confidence)")
            return false
        }
        
        // Additional validation logic can be added here
        // For example, checking for minimum word count, valid sentence structure, etc.
        
        return true
    }
    
    /// Processes and cleans transcribed text
    func processTranscription(_ text: String) -> String {
        // Remove excessive whitespace
        var processed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove common speech recognition artifacts
        processed = processed.replacingOccurrences(of: "um", with: "")
        processed = processed.replacingOccurrences(of: "uh", with: "")
        processed = processed.replacingOccurrences(of: "ah", with: "")
        
        // Capitalize first letter of sentences
        processed = processed.capitalizingFirstLetter()
        
        return processed
    }
    
    /// Analyzes speech segments for better interpretation
    func analyzeSpeechSegment(_ text: String) -> SpeechSegmentAnalysis {
        let sentiment = analyzeSentiment(text)
        let isPause = checkForPause(text)
        let isQuestion = text.contains("?") || text.lowercased().hasPrefix("what") || 
                        text.lowercased().hasPrefix("how") || text.lowercased().hasPrefix("why")
        
        return SpeechSegmentAnalysis(
            text: text,
            sentiment: sentiment,
            isPause: isPause,
            isQuestion: isQuestion
        )
    }
    
    private func analyzeSentiment(_ text: String) -> Float {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let sentiment = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        return Float(sentiment?.rawValue ?? "0") ?? 0
    }
    
    private func checkForPause(_ text: String) -> Bool {
        // Check for common pause indicators
        return text.contains("...") || text.contains(",") || text.hasSuffix(".")
    }
}

struct SpeechSegmentAnalysis {
    let text: String
    let sentiment: Float
    let isPause: Bool
    let isQuestion: Bool
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}
