import SwiftUI
import Speech
import Combine

@MainActor
class TranscriptionViewModel: ObservableObject {
    // Published properties
    @Published private(set) var isTranscribing = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var liveText = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var confidence: Float = 0
    @Published private(set) var selectedLanguage: Language
    @Published var showingError = false
    @Published var errorMessage: String?
    
    // Services
    private let speechRecognizer: SpeechRecognizer
    private let audioEngine: AudioEngine
    private let hapticEngine = PremiumDesignSystem.HapticEngine.shared
    
    // State
    private var recognitionTask: Task<Void, Error>?
    private var audioLevelTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    // Constants
    let availableLanguages = Language.supported
    
    var statusMessage: String {
        isTranscribing ? "Recording..." : "Ready"
    }
    
    init() {
        self.selectedLanguage = .english
        self.speechRecognizer = SpeechRecognizer()
        self.audioEngine = AudioEngine()
        
        setupSubscriptions()
    }
    
    func toggleTranscription() {
        if isTranscribing {
            stopTranscription()
        } else {
            startTranscription()
        }
    }
    
    func clearTranscription() {
        transcribedText = ""
        liveText = ""
        confidence = 0
    }
    
    func shareTranscription() {
        // Implement sharing functionality
    }
    
    func setLanguage(_ language: Language) {
        selectedLanguage = language
        // Update speech recognizer locale
    }
    
    private func startTranscription() {
        Task {
            do {
                isTranscribing = true
                hapticEngine.playFeedback(.recording)
                
                // Start audio monitoring
                audioLevelTask = startAudioLevelMonitoring()
                
                // Start speech recognition
                recognitionTask = try await speechRecognizer.startRecognition(
                    language: selectedLanguage
                ) { [weak self] result in
                    self?.handleRecognitionResult(result)
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    private func stopTranscription() {
        isTranscribing = false
        hapticEngine.playFeedback(.stopRecording)
        
        // Stop tasks
        recognitionTask?.cancel()
        audioLevelTask?.cancel()
        
        // Append final live text if any
        if !liveText.isEmpty {
            appendTranscribedText(liveText)
            liveText = ""
        }
    }
    
    private func startAudioLevelMonitoring() -> Task<Void, Error> {
        Task {
            for await level in audioEngine.levels {
                await MainActor.run {
                    self.audioLevel = level
                    
                    // Trigger warning if audio level is too low
                    if level < 0.1 && isTranscribing {
                        hapticEngine.playFeedback(.error)
                    }
                }
            }
        }
    }
    
    private func handleRecognitionResult(_ result: SpeechRecognizer.Result) {
        switch result {
        case .partial(let text):
            liveText = text
        case .final(let text, let confidence):
            appendTranscribedText(text)
            self.confidence = confidence
            liveText = ""
        }
    }
    
    private func appendTranscribedText(_ text: String) {
        if !transcribedText.isEmpty {
            transcribedText += "\n"
        }
        transcribedText += text
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
        stopTranscription()
    }
    
    private func setupSubscriptions() {
        // Add any necessary subscriptions
    }
}

struct Language: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    
    static let english = Language(code: "en-US", name: "English")
    static let swedish = Language(code: "sv-SE", name: "Swedish")
    
    static let supported = [english, swedish]
}
