import SwiftUI
import Speech

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status indicator
                HStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)
                    Text(viewModel.isRecording ? "Recording..." : "Ready")
                        .foregroundColor(.secondary)
                }
                
                // Transcribed text
                ScrollView {
                    Text(viewModel.transcribedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                if let language = viewModel.detectedLanguage {
                    Text("Detected Language: \(language)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            Task {
                                try await viewModel.startRecording()
                            }
                        }
                    }) {
                        Label(
                            viewModel.isRecording ? "Stop" : "Start",
                            systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: viewModel.clearTranscription) {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(viewModel.transcribedText.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Transcription")
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

struct TranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionView()
            .environmentObject(SettingsManager.shared)
    }
}
