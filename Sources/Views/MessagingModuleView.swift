import SwiftUI
import Combine

struct MessagingModuleView: View {
    @StateObject private var viewModel = MessagingViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            MessagingHeaderView(viewModel: viewModel)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id)
                    }
                }
            }
            
            // Input
            MessageInputView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showingAlert) {
            Button("OK") {
                viewModel.dismissAlert()
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onAppear {
            viewModel.loadMessages()
        }
    }
}

// MARK: - Subviews

struct MessagingHeaderView: View {
    @ObservedObject var viewModel: MessagingViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                LanguageButton(
                    language: viewModel.sourceLanguage,
                    isSource: true,
                    action: viewModel.showLanguageSelector
                )
                
                Button(action: viewModel.switchLanguages) {
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.title3)
                }
                
                LanguageButton(
                    language: viewModel.targetLanguage,
                    isSource: false,
                    action: viewModel.showLanguageSelector
                )
            }
            
            if viewModel.isTranslating {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
}

struct MessageBubbleView: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
            HStack {
                if message.isOutgoing {
                    Spacer()
                }
                
                VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .foregroundColor(message.isOutgoing ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            message.isOutgoing ?
                                Color.blue :
                                Color(UIColor.systemGray6)
                        )
                        .cornerRadius(16)
                    
                    if let translation = message.translation {
                        Text(translation)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                }
                
                if !message.isOutgoing {
                    Spacer()
                }
            }
            
            if message.isTranslated {
                HStack {
                    if !message.isOutgoing {
                        Spacer()
                    }
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    if message.isOutgoing {
                        Spacer()
                    }
                }
            }
        }
    }
}

struct MessageInputView: View {
    @ObservedObject var viewModel: MessagingViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Voice Input Button
                Button(action: viewModel.toggleVoiceInput) {
                    Image(systemName: viewModel.isRecording ? "waveform" : "mic")
                        .font(.title3)
                        .foregroundColor(viewModel.isRecording ? .red : .primary)
                        .frame(width: 32)
                }
                
                // Text Input
                TextField("Message", text: $viewModel.messageText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .disabled(viewModel.isRecording)
                
                // Send Button
                Button(action: viewModel.sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.messageText.isEmpty && !viewModel.isRecording)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Models

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let translation: String?
    let isTranslated: Bool
    let isOutgoing: Bool
    let timestamp: Date
    let sender: String
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel

@MainActor
class MessagingViewModel: ObservableObject {
    private let messagingService: MessagingService
    private let translationService: TranslationService
    private let speechRecognizer: SpeechRecognizer
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isTranslating = false
    @Published var isRecording = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    @Published var sourceLanguage = "English"
    @Published var targetLanguage = "Spanish"
    
    init(
        messagingService: MessagingService = .shared,
        translationService: TranslationService = .shared,
        speechRecognizer: SpeechRecognizer = .shared
    ) {
        self.messagingService = messagingService
        self.translationService = translationService
        self.speechRecognizer = speechRecognizer
        
        setupSubscriptions()
    }
    
    func sendMessage() {
        guard !messageText.isEmpty || isRecording else { return }
        
        Task {
            do {
                isTranslating = true
                
                let text = isRecording ?
                    try await speechRecognizer.stopRecordingAndGetText() :
                    messageText
                
                // Translate message
                let translation = try await translationService.translate(
                    text: text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                // Send message
                let message = try await messagingService.sendMessage(
                    text: text,
                    translation: translation
                )
                
                // Update UI
                messages.append(message)
                messageText = ""
                isTranslating = false
                
            } catch {
                showAlert(message: error.localizedDescription)
            }
        }
    }
    
    func loadMessages() {
        Task {
            do {
                let loadedMessages = try await messagingService.loadMessages()
                messages = loadedMessages
            } catch {
                showAlert(message: error.localizedDescription)
            }
        }
    }
    
    func toggleVoiceInput() {
        Task {
            do {
                if isRecording {
                    messageText = try await speechRecognizer.stopRecordingAndGetText()
                    isRecording = false
                } else {
                    try await speechRecognizer.startRecording()
                    isRecording = true
                }
            } catch {
                showAlert(message: error.localizedDescription)
            }
        }
    }
    
    func switchLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
    func showLanguageSelector() {
        // Implement language selection
    }
    
    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    func dismissAlert() {
        alertMessage = ""
        showingAlert = false
    }
    
    private func setupSubscriptions() {
        // Monitor speech recognition
        speechRecognizer.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.messageText = text
            }
            .store(in: &cancellables)
    }
}
