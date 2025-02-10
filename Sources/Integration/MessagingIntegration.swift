import Foundation
import os.log
import Combine

enum MessagingIntegrationError: Error, LocalizedError {
    case sendMessageFailed(Error)
    case invalidMessage
    case invalidPlatform(String)
    case integrationFailed(Error)
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .sendMessageFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .invalidMessage:
            return "Invalid message: The message cannot be empty"
        case .invalidPlatform(let platform):
            return "Invalid platform: \(platform) is not supported"
        case .integrationFailed(let error):
            return "Integration failed: \(error.localizedDescription)"
        case .notAuthorized:
            return "Not authorized to perform this action"
        }
    }
}

enum MessagingPlatform: String, CaseIterable {
    case appleMessages = "Apple Messages"
    case whatsapp = "WhatsApp"
    case telegram = "Telegram"
    case signal = "Signal"
    
    var identifier: String {
        switch self {
        case .appleMessages: return "com.apple.MobileSMS"
        case .whatsapp: return "net.whatsapp.WhatsApp"
        case .telegram: return "ph.telegra.Telegraph"
        case .signal: return "org.whispersystems.signal"
        }
    }
}

@MainActor
class MessagingIntegration: ObservableObject {
    private let backendManager: UnifiedBackendManager
    private let log = Logger(subsystem: "com.comprenanto", category: "MessagingIntegration")
    
    @Published private(set) var integratedPlatforms: Set<MessagingPlatform> = []
    @Published private(set) var isAuthorized = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(backendManager: UnifiedBackendManager) {
        self.backendManager = backendManager
        checkAuthorization()
    }
    
    func sendMessage(_ text: String) async throws {
        guard isAuthorized else {
            throw MessagingIntegrationError.notAuthorized
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MessagingIntegrationError.invalidMessage
        }
        
        do {
            try await backendManager.sendData(endpoint: "messages", data: ["text": text])
            log.info("Message sent successfully.")
        } catch {
            log.error("Error sending message: \(error)")
            throw MessagingIntegrationError.sendMessageFailed(error)
        }
    }
    
    func integrateWithPlatform(_ platform: MessagingPlatform) async throws {
        guard isAuthorized else {
            throw MessagingIntegrationError.notAuthorized
        }
        
        log.info("Integrating with \(platform.rawValue)")
        
        do {
            // Simulating integration process
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds delay
            
            // Here you would implement the actual integration logic
            // For example, requesting permissions, setting up API clients, etc.
            
            integratedPlatforms.insert(platform)
            log.info("Successfully integrated with \(platform.rawValue)")
        } catch {
            log.error("Failed to integrate with \(platform.rawValue): \(error)")
            throw MessagingIntegrationError.integrationFailed(error)
        }
    }
    
    func removeIntegration(for platform: MessagingPlatform) {
        integratedPlatforms.remove(platform)
        log.info("Removed integration for \(platform.rawValue)")
    }
    
    func isIntegrated(with platform: MessagingPlatform) -> Bool {
        integratedPlatforms.contains(platform)
    }
    
    private func checkAuthorization() {
        // Here you would implement logic to check if the user is authorized
        // This could involve checking user authentication status, device permissions, etc.
        
        // For this example, we'll use a simple Timer to simulate an authorization check
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.isAuthorized = true
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Integration

struct MessagingIntegrationView: View {
    @StateObject private var integration: MessagingIntegration
    @State private var messageText = ""
    @State private var selectedPlatform: MessagingPlatform?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(backendManager: UnifiedBackendManager) {
        _integration = StateObject(wrappedValue: MessagingIntegration(backendManager: backendManager))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Send Message")) {
                TextField("Message", text: $messageText)
                Button("Send") {
                    sendMessage()
                }
                .disabled(messageText.isEmpty || !integration.isAuthorized)
            }
            
            Section(header: Text("Integrated Platforms")) {
                ForEach(Array(integration.integratedPlatforms), id: \.self) { platform in
                    HStack {
                        Text(platform.rawValue)
                        Spacer()
                        Button("Remove") {
                            integration.removeIntegration(for: platform)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("Available Platforms")) {
                ForEach(MessagingPlatform.allCases.filter { !integration.isIntegrated(with: $0) }, id: \.self) { platform in
                    Button(platform.rawValue) {
                        selectedPlatform = platform
                    }
                }
            }
        }
        .navigationTitle("Messaging Integration")
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Message Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $selectedPlatform) { platform in
            IntegrationView(platform: platform, integration: integration)
        }
    }
    
    private func sendMessage() {
        Task {
            do {
                try await integration.sendMessage(messageText)
                messageText = ""
                showAlert("Message sent successfully")
            } catch {
                showAlert("Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

struct IntegrationView: View {
    let platform: MessagingPlatform
    @ObservedObject var integration: MessagingIntegration
    @Environment(\.presentationMode) var presentationMode
    @State private var isIntegrating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Integrate with \(platform.rawValue)")
                .font(.title)
            
            if isIntegrating {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                Button("Start Integration") {
                    startIntegration()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func startIntegration() {
        isIntegrating = true
        errorMessage = nil
        
        Task {
            do {
                try await integration.integrateWithPlatform(platform)
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isIntegrating = false
        }
    }
}

#Preview {
    NavigationView {
        MessagingIntegrationView(backendManager: UnifiedBackendManager(baseURL: "https://api.example.com"))
    }
}
</boltArtifact>

This enhanced implementation includes:

1. Async/await support for better concurrency handling.
2. More comprehensive error handling with localized error descriptions.
3. A `MessagingPlatform` enum for type-safe platform handling.
4. `@MainActor` annotation for proper main thread execution.
5. Combine integration for authorization status updates.
6. SwiftUI views for easy integration into your app.
7. Platform integration and removal functionality.
8. Preview support for SwiftUI views.

Key improvements:
- Async methods for sending messages and integrating platforms.
- Better error handling and propagation.
- Type-safe platform handling with `MessagingPlatform` enum.
- Reactive programming with Combine for authorization status.
- SwiftUI views for messaging integration and platform selection.
- Simulated integration process with proper error handling.
- Preview support for easier development and testing.

To use this in your app:

```swift
struct ContentView: View {
    let backendManager: UnifiedBackendManager
    
    var body: some View {
        NavigationView {
            MessagingIntegrationView(backendManager: backendManager)
        }
    }
}
```

This implementation provides a more robust and user-friendly messaging integration feature for your Comprenanto app. It allows users to send messages, integrate with various messaging platforms, and manage those integrations.

Would you like me to explain any part of this implementation in more detail or make any further modifications?
