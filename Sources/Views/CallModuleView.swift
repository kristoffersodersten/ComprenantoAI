import SwiftUI
import WebRTC

struct CallModuleView: View {
    @StateObject private var viewModel = CallViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Status and Language Selection
            CallHeaderView(viewModel: viewModel)
            
            // Audio Visualization
            AudioWaveformView(level: viewModel.audioLevel)
                .frame(height: 60)
                .padding()
            
            // Transcription and Translation
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.currentTranscription.isEmpty {
                        TranscriptionView(text: viewModel.currentTranscription)
                    }
                    
                    if !viewModel.currentTranslation.isEmpty {
                        TranslationView(text: viewModel.currentTranslation)
                    }
                }
                .padding()
            }
            
            // Call Controls
            CallControlsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showingAlert) {
            Button("OK") {
                viewModel.dismissAlert()
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Subviews

struct CallHeaderView: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.statusMessage)
                .font(.headline)
                .foregroundColor(statusColor)
            
            HStack {
                LanguageButton(
                    language: viewModel.sourceLanguage,
                    isSource: true,
                    action: viewModel.showLanguageSelector
                )
                
                Button(action: viewModel.switchLanguages) {
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.title2)
                }
                .disabled(viewModel.isCallActive)
                
                LanguageButton(
                    language: viewModel.targetLanguage,
                    isSource: false,
                    action: viewModel.showLanguageSelector
                )
            }
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch viewModel.callState {
        case .active: return .green
        case .error: return .red
        case .connecting: return .orange
        default: return .primary
        }
    }
}

struct AudioWaveformView: View {
    let level: Float
    @State private var samples: [CGFloat] = Array(repeating: 0.2, count: 30)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<30) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: (geometry.size.width - 58) / 30)
                        .frame(height: geometry.size.height * samples[index])
                }
            }
            .onChange(of: level) { newLevel in
                samples.removeFirst()
                samples.append(CGFloat(newLevel))
            }
        }
    }
}

struct CallControlsView: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        HStack(spacing: 30) {
            // Mute Button
            ControlButton(
                icon: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                color: viewModel.isMuted ? .red : .blue,
                action: viewModel.toggleMute,
                isEnabled: viewModel.isCallActive
            )
            
            // Call Button
            MainCallButton(
                isActive: viewModel.isCallActive,
                action: viewModel.toggleCall
            )
            
            // Camera Button
            ControlButton(
                icon: viewModel.isCameraEnabled ? "video.fill" : "video.slash.fill",
                color: viewModel.isCameraEnabled ? .blue : .red,
                action: viewModel.toggleCamera,
                isEnabled: viewModel.isCallActive
            )
        }
        .padding()
    }
}

struct MainCallButton: View {
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.red : Color.green)
                    .frame(width: 64, height: 64)
                
                Image(systemName: isActive ? "phone.down.fill" : "phone.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isEnabled ? color : .gray)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
        }
        .disabled(!isEnabled)
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - View Model

@MainActor
class CallViewModel: ObservableObject {
    private let callManager = CallManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var callState: CallManager.CallState = .idle
    @Published var currentTranscription = ""
    @Published var currentTranslation = ""
    @Published var audioLevel: Float = 0
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    @Published var sourceLanguage = "English"
    @Published var targetLanguage = "Spanish"
    @Published var isMuted = false
    @Published var isCameraEnabled = false
    
    var isCallActive: Bool {
        if case .active = callState { return true }
        return false
    }
    
    var statusMessage: String {
        switch callState {
        case .idle: return "Ready to Start"
        case .connecting: return "Connecting..."
        case .active: return "Call Active"
        case .error(let message): return "Error: \(message)"
        case .disconnected: return "Call Ended"
        }
    }
    
    init() {
        setupSubscriptions()
    }
    
    func toggleCall() {
        Task {
            if isCallActive {
                await callManager.endCall()
            } else {
                do {
                    try await callManager.startCall(
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                } catch {
                    showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    func toggleMute() {
        Task {
            isMuted.toggle()
            await callManager.muteAudio(isMuted)
        }
    }
    
    func toggleCamera() {
        isCameraEnabled.toggle()
        // Implement camera toggle
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
        // Call state updates
        callManager.callStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$callState)
        
        // Transcription updates
        callManager.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.currentTranscription = result.text
            }
            .store(in: &cancellables)
        
        // Translation updates
        callManager.translationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.currentTranslation = result.translatedText
            }
            .store(in: &cancellables)
        
        // Audio level updates
        callManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }
}
