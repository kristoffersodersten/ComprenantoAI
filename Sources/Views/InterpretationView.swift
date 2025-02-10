import SwiftUI

struct InterpretationView: View {
    @StateObject private var viewModel = InterpretationViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Language selector and controls
            HStack {
                LanguageButton(
                    language: viewModel.sourceLanguage,
                    isSource: true
                )
                
                Button(action: viewModel.switchLanguages) {
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.title2)
                }
                
                LanguageButton(
                    language: viewModel.targetLanguage,
                    isSource: false
                )
            }
            .padding()
            
            // Audio visualization
            AudioLevelView(level: viewModel.audioLevel)
                .frame(height: 60)
                .padding()
            
            // Transcription and translation
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TranscriptionView(text: viewModel.sourceTranscript)
                    
                    if !viewModel.translation.isEmpty {
                        TranslationView(text: viewModel.translation)
                    }
                }
                .padding()
            }
            
            // Control button
            ControlButton(
                isActive: viewModel.isSessionActive,
                action: {
                    if viewModel.isSessionActive {
                        viewModel.stopSession()
                    } else {
                        viewModel.startSession()
                    }
                }
            )
            .padding(.bottom)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

struct LanguageButton: View {
    let language: String
    let isSource: Bool
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Text(Locale.current.localizedString(forLanguageCode: language) ?? language)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
    }
}

struct AudioLevelView: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<30) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .opacity(level > Float(index) / 30.0 ? 1 : 0.2)
                }
            }
        }
    }
}

struct TranscriptionView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transcription")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
        }
    }
}

struct TranslationView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Translation")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
        }
    }
}

struct ControlButton: View {
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(isActive ? .red : .accentColor)
        }
    }
}
