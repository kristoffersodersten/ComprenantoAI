import NaturalLanguage
import Combine
import os.log

// Add notification name extension
extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageManagerDidChangeLanguage")
    static let languageDetected = Notification.Name("LanguageDetectorDidDetectLanguage")
}

actor LanguageDetector {
    static let shared = LanguageDetector()
    
    // Core properties
    private let log = Logger(subsystem: "com.comprenanto", category: "LanguageDetection")
    private let recognizer = NLLanguageRecognizer()
    
    // Publishers
    let detectionPublisher = PassthroughSubject<LanguageDetectionResult, Never>()
    let languageChangePublisher = PassthroughSubject<Language, Never>()
    
    // Current language tracking
    private(set) var currentLanguage: Language?
    
    // Rest of the existing implementation remains the same...
    
    // Add new method for simple detection
    func quickDetect(text: String) async throws -> Language {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LanguageError.invalidInput
        }
        
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text
        
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .word, scheme: .language)
        
        guard let languageCode = tag?.rawValue else {
            throw LanguageError.detectionFailed("Could not determine language")
        }
        
        let language = try languageFromCode(languageCode)
        
        // Update current language if it changed
        if currentLanguage != language {
            currentLanguage = language
            languageChangePublisher.send(language)
            
            // Post notification for legacy support
            await NotificationCenter.default.post(
                name: .languageDidChange,
                object: self,
                userInfo: ["language": language]
            )
        }
        
        return language
    }
    
    // Add method for continuous detection
    func startContinuousDetection(
        textStream: AsyncStream<String>
    ) -> AsyncStream<LanguageDetectionResult> {
        AsyncStream { continuation in
            Task {
                for await text in textStream {
                    do {
                        let result = try await detectLanguage(in: text)
                        continuation.yield(result)
                    } catch {
                        log.error("Continuous detection error: \(error.localizedDescription)")
                    }
                }
                continuation.finish()
            }
        }
    }
}

// Add convenience methods
extension LanguageDetector {
    func detectLanguageSync(_ text: String) async throws -> String {
        let language = try await quickDetect(text: text)
        return language.code
    }
    
    func detectLanguageWithFallback(_ text: String, fallback: String = "en") async -> String {
        do {
            return try await detectLanguageSync(text)
        } catch {
            log.error("Language detection failed, using fallback: \(error.localizedDescription)")
            return fallback
        }
    }
}

// Usage example for continuous detection
extension LanguageDetector {
    static func continuousExample() async {
        let detector = LanguageDetector.shared
        
        // Create a stream of text input
        let textStream = AsyncStream<String> { continuation in
            // Simulate text input
            Task {
                let texts = [
                    "Hello, how are you?",
                    "¿Cómo estás?",
                    "Bonjour!",
                    "こんにちは"
                ]
                
                for text in texts {
                    continuation.yield(text)
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
                continuation.finish()
            }
        }
        
        // Start continuous detection
        let detectionStream = await detector.startContinuousDetection(textStream: textStream)
        
        for await result in detectionStream {
            print("Detected: \(result.primaryLanguage.name) (\(result.confidence))")
        }
    }
}
