import Intents
import SwiftUI
import os.log

enum ShortcutError: Error {
    case intentCreationFailed
    case donationFailed(Error)
    case invalidAction
    case handlingFailed(Error)
}

class ShortcutManager: NSObject, INInteractionDelegate {
    static let shared = ShortcutManager()
    
    private let log = Logger(subsystem: "com.comprenanto", category: "Shortcuts")
    private var handlers: [ShortcutAction: () -> Void] = [:]
    
    // MARK: - Types
    
    enum ShortcutAction: String, CaseIterable, Identifiable, Codable {
        case transcribe
        case sendMessage
        case translate
        case startCall
        case quickNote
        
        var id: String { rawValue }
        
        var phrase: String {
            switch self {
            case .transcribe: return "Start Transcription"
            case .sendMessage: return "Send Message"
            case .translate: return "Quick Translate"
            case .startCall: return "Start Call"
            case .quickNote: return "New Note"
            }
        }
        
        var icon: String {
            switch self {
            case .transcribe: return "waveform"
            case .sendMessage: return "message.fill"
            case .translate: return "globe"
            case .startCall: return "phone.fill"
            case .quickNote: return "note.text"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func addShortcut(for action: ShortcutAction) async throws {
        do {
            let intent = try createIntent(for: action)
            let interaction = INInteraction(intent: intent, response: nil)
            
            try await interaction.donate()
            log.info("Successfully added shortcut for action: \(action.rawValue)")
            
        } catch {
            log.error("Failed to add shortcut: \(error.localizedDescription)")
            throw ShortcutError.donationFailed(error)
        }
    }
    
    func registerHandler(for action: ShortcutAction, handler: @escaping () -> Void) {
        handlers[action] = handler
        log.info("Registered handler for action: \(action.rawValue)")
    }
    
    func removeShortcut(for action: ShortcutAction) async throws {
        let center = INInteractionCenter.default
        await center.deleteAllInteractions()
        log.info("Removed shortcut for action: \(action.rawValue)")
    }
    
    // MARK: - Intent Handling
    
    func handleIntent(_ intent: INIntent) {
        switch intent {
        case is INStartAudioRecordingIntent:
            handlers[.transcribe]?()
        case is INSendMessageIntent:
            handlers[.sendMessage]?()
        default:
            log.error("Unknown intent type: \(intent)")
        }
    }
    
    // MARK: - Private Methods
    
    private func createIntent(for action: ShortcutAction) throws -> INIntent {
        switch action {
        case .transcribe:
            let intent = INStartAudioRecordingIntent()
            intent.suggestedInvocationPhrase = action.phrase
            return intent
            
        case .sendMessage:
            let intent = INSendMessageIntent()
            intent.recipients = [createDefaultRecipient()]
            intent.content = "Quick message"
            intent.suggestedInvocationPhrase = action.phrase
            return intent
            
        case .translate:
            // Custom intent for translation
            let intent = INStartAudioRecordingIntent() // Placeholder
            intent.suggestedInvocationPhrase = action.phrase
            return intent
            
        case .startCall:
            let intent = INStartCallIntent()
            intent.suggestedInvocationPhrase = action.phrase
            return intent
            
        case .quickNote:
            let intent = INCreateNoteIntent()
            intent.suggestedInvocationPhrase = action.phrase
            return intent
        }
    }
    
    private func createDefaultRecipient() -> INPerson {
        INPerson(
            personHandle: INPersonHandle(value: "default@example.com", type: .emailAddress),
            nameComponents: nil,
            displayName: "Default Recipient",
            image: nil,
            contactIdentifier: nil,
            customIdentifier: nil
        )
    }
}

// MARK: - SwiftUI Integration

struct ShortcutButton: View {
    let action: ShortcutManager.ShortcutAction
    let handler: () -> Void
    
    var body: some View {
        Button(action: {
            Task {
                try? await ShortcutManager.shared.addShortcut(for: action)
                handler()
            }
        }) {
            Label(action.phrase, systemImage: action.icon)
        }
    }
}

struct ShortcutsList: View {
    var body: some View {
        List(ShortcutManager.ShortcutAction.allCases) { action in
            ShortcutRow(action: action)
        }
    }
}

struct ShortcutRow: View {
    let action: ShortcutManager.ShortcutAction
    @State private var isEnabled = false
    
    var body: some View {
        HStack {
            Label(action.phrase, systemImage: action.icon)
            Spacer()
            Toggle("", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    Task {
                        if newValue {
                            try? await ShortcutManager.shared.addShortcut(for: action)
                        } else {
                            try? await ShortcutManager.shared.removeShortcut(for: action)
                        }
                    }
                }
        }
    }
}

// MARK: - Usage Example

struct ShortcutsView: View {
    var body: some View {
        List {
            Section(header: Text("Available Shortcuts")) {
                ShortcutsList()
            }
            
            Section(header: Text("Quick Actions")) {
                ShortcutButton(action: .transcribe) {
                    print("Starting transcription...")
                }
                
                ShortcutButton(action: .translate) {
                    print("Starting translation...")
                }
            }
        }
        .navigationTitle("Shortcuts")
        .onAppear {
            setupShortcutHandlers()
        }
    }
    
    private func setupShortcutHandlers() {
        let manager = ShortcutManager.shared
        
        manager.registerHandler(for: .transcribe) {
            print("Handling transcribe shortcut")
        }
        
        manager.registerHandler(for: .sendMessage) {
            print("Handling send message shortcut")
        }
    }
}

#Preview {
    NavigationView {
        ShortcutsView()
    }
}
