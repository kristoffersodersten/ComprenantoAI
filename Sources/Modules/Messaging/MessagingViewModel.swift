import SwiftUI
import Combine

class MessagingViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMessage = ""
    @Published var translatedMessage = ""
    @Published var retranslatedMessage = ""
    @Published var isTranslating = false
    @Published var culturalSuggestion: String?
    
    private var translationService: TranslationService
    private var culturalAwarenessService: CulturalAwarenessService
    
    init(translationService: TranslationService = TranslationService(),
         culturalAwarenessService: CulturalAwarenessService = CulturalAwarenessService()) {
        self.translationService = translationService
        self.culturalAwarenessService = culturalAwarenessService
    }
    
    func sendMessage() {
        guard !currentMessage.isEmpty else { return }
        
        isTranslating = true
        
        Task {
            do {
                let translation = try await translationService.translate(currentMessage, to: "targetLanguage")
                let retranslation = try await translationService.translate(translation, to: "sourceLanguage")
                
                await MainActor.run {
                    self.translatedMessage = translation
                    self.retranslatedMessage = retranslation
                    
                    let newMessage = Message(text: currentMessage, translation: translation, isOutgoing: true)
                    self.messages.append(newMessage)
                    
                    self.checkCulturalAwareness(message: currentMessage)
                    
                    self.currentMessage = ""
                    self.isTranslating = false
                }
            } catch {
                print("Translation error: \(error)")
                self.isTranslating = false
            }
        }
    }
    
    private func checkCulturalAwareness(message: String) {
        Task {
            if let suggestion = try? await culturalAwarenessService.checkMessage(message) {
                await MainActor.run {
                    self.culturalSuggestion = suggestion
                }
            }
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let translation: String?
    let isOutgoing: Bool
}

class TranslationService {
    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        // Simulera översättning
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Translated: \(text)"
    }
}

class CulturalAwarenessService {
    func checkMessage(_ message: String) async throws -> String? {
        // Simulera kulturell medvetenhet
        try await Task.sleep(nanoseconds: 500_000_000)
        return "Consider rephrasing for better cultural context"
    }
}
