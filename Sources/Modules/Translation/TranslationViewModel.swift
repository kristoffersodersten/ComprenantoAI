import SwiftUI
import Combine

@MainActor
class TranslationViewModel: ObservableObject {
    // Published properties
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published private(set) var isTranslating = false
    @Published private(set) var isRecording = false
    @Published var sourceLanguage: Language
    @Published var targetLanguage: Language
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var activeField: TranslationField = .source
    
    // Services
    private let translationService: TranslationService
    private let speechRecognizer: SpeechRecognizer
    private let ttsService: TTSService
    private let hapticEngine = PremiumDesignSystem.HapticEngine.shared
    
    // State
    private var translationTask: Task<Void, Error>?
    private var recordingTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        translationService: TranslationService = TranslationService(),
        speechRecognizer: SpeechRecognizer = SpeechRecognizer(),
        ttsService: TTSService = TTSService()
    ) {
        self.translationService = translationService
        self.speechRecognizer = speechRecognizer
        self.ttsService = ttsService
        self.sourceLanguage = .english
        self.targetLanguage = .swedish
        
        setupSubscriptions()
    }
    
    func translate() {
        guard !sourceText.isEmpty else { return }
        
        isTranslating = true
        hapticEngine.playFeedback(.mediumTap)
        
        translationTask = Task {
            do {
                let result = try await translationService.translate(
                    text: sourceText,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                await MainActor.run {
                    self.translatedText = result
                    self.isTranslating = false
                    self.hapticEngine.playFeedback(.success)
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                }
            }
        }
    }
    
    func toggleVoiceInput() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func swapLanguages() {
        swap(&sourceLanguage, &targetLanguage)
        swap(&sourceText, &translatedText)
        hapticEngine.playFeedback(.mediumTap)
    }
    
    func showLanguageSelector(for type: LanguageType) {
        // Implement language selection
        hapticEngine.playFeedback(.lightTap)
    }
    
    func speakTranslation() {
        Task {
            do {
                try await ttsService.speak(text: translatedText, language: targetLanguage)
                hapticEngine.playFeedback(.success)
            } catch {
                handleError(error)
            }
        }
    }
    
    func setActiveField(_ field: TranslationField) {
        activeField = field
        hapticEngine.playFeedback(.lightTap)
    }
    
    private func startRecording() {
        isRecording = true
        hapticEngine.playFeedback(.recording)
        
        recordingTask = Task {
            do {
                let recognizedText = try await speechRecognizer.startRecognition(language: sourceLanguage)
                await MainActor.run {
                    self.sourceText = recognizedText
                    self.stopRecording()
                    self.translate()
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        hapticEngine.playFeedback(.stopRecording)
        recordingTask?.cancel()
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
        isTranslating = false
        isRecording = false
        hapticEngine.playFeedback(.error)
    }
    
    private func setupSubscriptions() {
        // Add any necessary subscriptions
    }
}

enum LanguageType {
    case source
    case target
}

enum TranslationField {
    case source
    case target
}

struct Language {
    let code: String
    let name: String
    let textAlignment: TextAlignment
    let layoutDirection: LayoutDirection
    
    static let english = Language(code: "en", name: "English", textAlignment: .leading, layoutDirection: .leftToRight)
    static let swedish = Language(code: "sv", name: "Swedish", textAlignment: .leading, layoutDirection: .leftToRight)
    static let arabic = Language(code: "ar", name: "Arabic", textAlignment: .trailing, layoutDirection: .rightToLeft)
    // Add more languages as needed
}

struct TranslationService {
    func translate(text: String, from source: Language, to target: Language) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        // Here you would implement actual translation logic
        return "Translated: \(text)"
    }
}

struct TTSService {
    func speak(text: String, language: Language) async throws {
        // Implement text-to-speech functionality
        print("Speaking: \(text) in \(language.name)")
    }
}
