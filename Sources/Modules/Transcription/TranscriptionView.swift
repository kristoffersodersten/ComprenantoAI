import SwiftUI
import Speech

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            TranscriptionStatusBar(viewModel: viewModel)
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.transcribedText.isEmpty {
                        TranscribedTextView(
                            text: viewModel.transcribedText,
                            confidence: viewModel.confidence
                        )
                    }
                    
                    if viewModel.isTranscribing {
                        LiveTranscriptionView(
                            text: viewModel.liveText,
                            audioLevel: viewModel.audioLevel
                        )
                    }
                }
                .padding()
            }
            
            // Control bar
            TranscriptionControlBar(viewModel: viewModel)
        }
        .navigationTitle("Transcription")
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

struct TranscriptionStatusBar: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    
    var body: some View {
        HStack {
            // Language selector
            Menu {
                ForEach(viewModel.availableLanguages, id: \.code) { language in
                    Button(language.name) {
                        viewModel.setLanguage(language)
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedLanguage.name)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isTranscribing ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)
                    .premiumPulse(isActive: viewModel.isTranscribing)
                
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}

struct TranscribedTextView: View {
    let text: String
    let confidence: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(Int(confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LiveTranscriptionView: View {
    let text: String
    let audioLevel: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .opacity(0.8)
            
            AudioLevelIndicator(level: audioLevel)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TranscriptionControlBar: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            // Clear button
            Button(action: viewModel.clearTranscription) {
                Image(systemName: "trash")
                    .font(.title2)
            }
            .disabled(viewModel.transcribedText.isEmpty)
            
            // Record button
            Button(action: viewModel.toggleTranscription) {
                ZStack {
                    Circle()
                        .fill(viewModel.isTranscribing ? Color.red : Color.accentColor)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: viewModel.isTranscribing ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .premiumButtonStyle(
                feedback: viewModel.isTranscribing ? .stopRecording : .recording
            )
            
            // Share button
            Button(action: viewModel.shareTranscription) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
            }
            .disabled(viewModel.transcribedText.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<30) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(
                            width: (geometry.size.width - 58) / 30,
                            height: geometry.size.height * CGFloat(level)
                        )
                }
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.1), value: level)
    }
}
