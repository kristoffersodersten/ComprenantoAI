import Foundation
import os.log

enum DataError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Could not find file: \(filename)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .invalidData:
            return "The data is invalid or corrupted"
        }
    }
}

actor DataManager {
    static let shared = DataManager()
    
    private let log = Logger(subsystem: "com.comprenanto", category: "DataManager")
    
    // MARK: - Types
    
    struct AppSettings: Codable {
        let languages: [String]
        let voices: [String]
        let maxTextLength: Int
        let supportedFormats: [String]
        
        static let `default` = AppSettings(
            languages: ["en", "es", "fr", "de", "it", "pt", "nl", "ja", "ko", "zh"],
            voices: ["alloy", "echo", "fable", "onyx", "nova", "shimmer"],
            maxTextLength: 1000,
            supportedFormats: ["mp3", "wav", "ogg"]
        )
    }
    
    struct Language: Codable, Identifiable, Hashable {
        let code: String
        let name: String
        let nativeName: String?
        let flag: String?
        let supportedFeatures: [Feature]
        
        var id: String { code }
        
        enum Feature: String, Codable {
            case translation
            case tts
            case transcription
        }
    }
    
    struct LanguageResponse: Codable {
        let languages: [Language]
    }
    
    // MARK: - Public Methods
    
    func getSettings() async -> AppSettings {
        // In a real app, you might load this from a server or local storage
        return AppSettings.default
    }
    
    func getLanguages() async throws -> [Language] {
        do {
            let languages = try await loadLanguagesFromFile()
            log.info("Successfully loaded \(languages.count) languages")
            return languages
        } catch {
            log.error("Failed to load languages: \(error.localizedDescription)")
            return getFallbackLanguages()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadLanguagesFromFile() async throws -> [Language] {
        guard let url = Bundle.main.url(forResource: "languages", withExtension: "json") else {
            throw DataError.fileNotFound("languages.json")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(LanguageResponse.self, from: data)
            return response.languages
        } catch {
            throw DataError.decodingFailed(error)
        }
    }
    
    private func getFallbackLanguages() -> [Language] {
        [
            Language(code: "en", name: "English", nativeName: "English", flag: "🇺🇸", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷", supportedFeatures: [.translation, .tts, .transcription]),
            Language(code: "zh", name: "Chinese", nativeName: "中文", flag: "🇨🇳", supportedFeatures: [.translation, .tts, .transcription])
        ]
    }
}

// MARK: - SwiftUI Views

struct LanguageSelectionView: View {
    @State private var languages: [DataManager.Language] = []
    @State private var errorMessage: String?
    @Binding var selectedLanguage: String
    
    var body: some View {
        List {
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                ForEach(languages) { language in
                    LanguageRow(language: language, isSelected: language.code == selectedLanguage)
                        .onTapGesture {
                            selectedLanguage = language.code
                        }
                }
            }
        }
        .task {
            do {
                languages = try await DataManager.shared.getLanguages()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct LanguageRow: View {
    let language: DataManager.Language
    let isSelected: Bool
    
    var body: some View {
        HStack {
            if let flag = language.flag {
                Text(flag)
            }
            
            VStack(alignment: .leading) {
                Text(language.name)
                    .font(.headline)
                
                if let nativeName = language.nativeName {
                    Text(nativeName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview Support

#Preview {
    NavigationView {
        LanguageSelectionView(selectedLanguage: .constant("en"))
            .navigationTitle("Select Language")
    }
}
