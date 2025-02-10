import SwiftUI

struct TranslationView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Language selection
                HStack {
                    LanguageButton(
                        language: viewModel.sourceLanguage,
                        isSource: true,
                        action: { viewModel.showLanguageSelector(isSource: true) }
                    )
                    
                    Button(action: viewModel.switchLanguages) {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.title2)
                    }
                    
                    LanguageButton(
                        language: viewModel.targetLanguage,
                        isSource: false,
                        action: { viewModel.showLanguageSelector(isSource: false) }
                    )
                }
                
                // Input text
                TextEditor(text: $viewModel.inputText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                // Translate button
                Button(action: {
                    Task {
                        await viewModel.translate()
                    }
                }) {
                    if viewModel.isTranslating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Translate")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputText.isEmpty || viewModel.isTranslating)
                
                // Translation result
                if !viewModel.translatedText.isEmpty {
                    ScrollView {
                        Text(viewModel.translatedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Translation")
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $viewModel.showingLanguageSelector) {
                LanguageSelectorView(
                    selectedLanguage: viewModel.isSelectingSource ? $viewModel.sourceLanguage : $viewModel.targetLanguage,
                    isSource: viewModel.isSelectingSource
                )
            }
        }
    }
}

struct LanguageButton: View {
    let language: SettingsManager.Language
    let isSource: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.name)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct TranslationView_Previews: PreviewProvider {
    static var previews: some View {
        TranslationView()
            .environmentObject(SettingsManager.shared)
    }
}
