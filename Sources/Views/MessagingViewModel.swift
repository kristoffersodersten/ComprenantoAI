import Combine
import Foundation
import os.log

enum MessagingError: Error {
    case sendFailed(Error)
    case translationFailed(Error)
    case loadFailed(Error)
    case invalidInput(String)
    case networkError(Error)
}

@MainActor
final class MessagingViewModel: ObservableObject {
    // Services
    private let messagingService: MessagingService
    private let translationService: TranslationService
    private let speechRecognizer: SpeechRecognizer
    private let log = Logger(subsystem: "com.comprenanto", category: "Messaging")
    
    // State
    @Published private(set) var messages: [Message] = []
    @Published private(set) var messageState: MessageState = .idle
    @Published var messageText = ""
    @Published var sourceLanguage: Language
    @Published var targetLanguage: Language
    
    // Derived state
    var isProcessing: Bool {
        if case .processing = messageState { return true }
        return false
    }
    
    // Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Types
    
    enum MessageState: Equatable {
        case idle
        case processing(ProcessingType)
        case error(String)
        
        enum ProcessingType {
            case sending
            case translating
            case recording
        }
    }
    
    struct Message: Identifiable, Codable, Equatable {
        let id: UUID
        let text: String
        let translation: String?
        let sourceLanguage: Language
        let targetLanguage: Language
        let timestamp: Date
        let status: Status
        let metadata: Metadata?
        
        enum Status: String, Codable {
            case sending
            case sent
            case translated
            case failed
        }
        
        struct Metadata: Codable {
            let confidence: Double?
            let retranslation: String?
            let processingTime: TimeInterval?
        }
    }
    
    struct Language: Codable, Equatable, Hashable {
        let code: String
        let name: String
        let isRTL: Bool
        
        static let english = Language(code: "en", name: "English", isRTL: false)
        static let spanish = Language(code: "es", name: "Spanish", isRTL: false)
    }
    
    // MARK: - Initialization
    
    init(
        messagingService: MessagingService = .shared,
        translationService: TranslationService = .shared,
        speechRecognizer: SpeechRecognizer = .shared,
        sourceLanguage: Language = .english,
        targetLanguage: Language = .spanish
    ) {
        self.messagingService = messagingService
        self.translationService = translationService
        self.speechRecognizer = speechRecognizer
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func sendMessage() async throws {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MessagingError.invalidInput("Empty message")
        }
        
        messageState = .processing(.sending)
        
        do {
            // Create pending message
            let pendingMessage = Message(
                id: UUID(),
                text: messageText,
                translation: nil,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                timestamp: Date(),
                status: .sending,
                metadata: nil
            )
            
            // Add to messages
            messages.append(pendingMessage)
            
            // Start translation
            messageState = .processing(.translating)
            
            let translation = try await translationService.translate(
                text: messageText,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            // Create final message
            let finalMessage = Message(
                id: pendingMessage.id,
                text: messageText,
                translation: translation,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                timestamp: Date(),
                status: .translated,
                metadata: Message.Metadata(
                    confidence: 1.0,
                    retranslation: nil,
                    processingTime: Date().timeIntervalSince(pendingMessage.timestamp)
                )
            )
            
            // Update message
            if let index = messages.firstIndex(where: { $0.id == pendingMessage.id }) {
                messages[index] = finalMessage
            }
            
            // Send to backend
            try await messagingService.sendMessage(finalMessage)
            
            // Clear input
            messageText = ""
            messageState = .idle
            
        } catch {
            messageState = .error(error.localizedDescription)
            throw MessagingError.sendFailed(error)
        }
    }
    
    func loadMessages() async throws {
        messageState = .processing(.sending)
        
        do {
            let loadedMessages = try await messagingService.loadMessages()
            messages = loadedMessages.sorted(by: { $0.timestamp < $1.timestamp })
            messageState = .idle
        } catch {
            messageState = .error(error.localizedDescription)
            throw MessagingError.loadFailed(error)
        }
    }
    
    func retranslate(_ message: Message) async throws {
        guard let translation = message.translation else { return }
        
        do {
            let retranslation = try await translationService.translate(
                text: translation,
                from: message.targetLanguage,
                to: message.sourceLanguage
            )
            
            // Update message with retranslation
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = message
                updatedMessage.metadata = Message.Metadata(
                    confidence: message.metadata?.confidence,
                    retranslation: retranslation,
                    processingTime: message.metadata?.processingTime
                )
                messages[index] = updatedMessage
            }
        } catch {
            throw MessagingError.translationFailed(error)
        }
    }
    
    func switchLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Monitor message text changes
        $messageText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard !text.isEmpty else { return }
                self?.handleMessageTextChange(text)
            }
            .store(in: &cancellables)
        
        // Monitor speech recognition
        speechRecognizer.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.messageText = text
            }
            .store(in: &cancellables)
    }
    
    private func handleMessageTextChange(_ text: String) {
        // Implement real-time translation preview or other features
    }
}

// MARK: - Preview Support

extension MessagingViewModel {
    static var preview: MessagingViewModel {
        let viewModel = MessagingViewModel()
        viewModel.messages = [
            Message(
                id: UUID(),
                text: "Hello, how are you?",
                translation: "¿Hola, cómo estás?",
                sourceLanguage: .english,
                targetLanguage: .spanish,
                timestamp: Date(),
                status: .translated,
                metadata: nil
            ),
            Message(
                id: UUID(),
                text: "I'm doing well, thanks!",
                translation: "¡Estoy bien, gracias!",
                sourceLanguage: .english,
                targetLanguage: .spanish,
                timestamp: Date(),
                status: .translated,
                metadata: nil
            )
        ]
        return viewModel
    }
}
