import SwiftUI

struct TranslationView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Language selection bar
            LanguageSelectionBar(viewModel: viewModel)
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // Source text input
                    TranslationTextView(
                        text: $viewModel.sourceText,
                        language: viewModel.sourceLanguage,
                        isSource: true,
                        isActive: viewModel.activeField == .source
                    ) {
                        viewModel.setActiveField(.source)
                    }
                    
                    // Translation output
                    TranslationTextView(
                        text: $viewModel.translatedText,
                        language: viewModel.targetLanguage,
                        isSource: false,
                        isActive: viewModel.activeField == .target
                    ) {
                        viewModel.setActiveField(.target)
                    }
                }
                .padding()
            }
            
            // Control bar
            TranslationControlBar(viewModel: viewModel)
        }
        .navigationTitle("Translation")
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

struct LanguageSelectionBar: View {
    @ObservedObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack {
            LanguageButton(
                language: viewModel.sourceLanguage,
                action: { viewModel.showLanguageSelector(for: .source) }
            )
            
            Button(action: viewModel.swapLanguages) {
                Image(systemName: "arrow.right.arrow.left")
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .foregroundColor(.accentColor)
            }
            .premiumButtonStyle(feedback: .mediumTap)
            
            LanguageButton(
                language: viewModel.targetLanguage,
                action: { viewModel.showLanguageSelector(for: .target) }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}

struct LanguageButton: View {
    let language: Language
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.name)
                    .font(.system(size: 16, weight: .medium, design: .default))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium, design: .default))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .premiumButtonStyle(feedback: .lightTap)
    }
}

struct TranslationTextView: View {
    @Binding var text: String
    let language: Language
    let isSource: Bool
    let isActive: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: language.textAlignment) {
            HStack {
                if !isSource {
                    Spacer()
                }
                Text(isSource ? "Original" : "Translation")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                if isSource {
                    Spacer()
                }
            }
            
            TextEditor(text: $text)
                .font(.system(size: 18, weight: .regular, design: .default))
                .frame(height: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .environment(\.layoutDirection, language.layoutDirection)
                .multilineTextAlignment(language.textAlignment == .leading ? .leading : .trailing)
                .premiumGlow(isActive: isActive)
            
            if isSource {
                HStack {
                    Spacer()
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .opacity(text.isEmpty ? 0 : 1)
                }
            }
        }
        .onTapGesture(perform: onTap)
    }
}

struct TranslationControlBar: View {
    @ObservedObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            // Voice input button
            Button(action: viewModel.toggleVoiceInput) {
                Image(systemName: viewModel.isRecording ? "waveform" : "mic")
                    .font(.system(size: 24, weight: .medium, design: .default))
                    .foregroundColor(viewModel.isRecording ? .red : .accentColor)
            }
            .premiumButtonStyle(feedback: .mediumTap)
            
            // Translate button
            Button(action: viewModel.translate) {
                Text("Translate")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .premiumButtonStyle(feedback: .heavyTap)
            .disabled(viewModel.sourceText.isEmpty || viewModel.isTranslating)
            
            // TTS button
            Button(action: viewModel.speakTranslation) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 24, weight: .medium, design: .default))
            }
            .premiumButtonStyle(feedback: .lightTap)
            .disabled(viewModel.translatedText.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
