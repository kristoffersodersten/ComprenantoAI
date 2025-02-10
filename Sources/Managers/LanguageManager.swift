import Foundation
import NaturalLanguage
import os.log

class LanguageDetector {
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "LanguageDetector")

    /// Detekterar språk från en given text.
    func detectLanguage(for text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log.error("Language detection failed: Empty text input")
            completion(.failure(NSError(domain: "LanguageDetection",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Input text is empty"])))
            return
        }

        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text

        // ✅ Använd `unit: .word` istället för `.paragraph`
        let (language, _) = tagger.tag(at: text.startIndex, unit: .word, scheme: .language)
        if let language = language?.rawValue {
            log.info("Detected language: \(language)")
            completion(.success(language))
        } else {
            log.error("Language detection failed: Could not determine language")
            completion(.failure(NSError(domain: "LanguageDetection",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Could not detect language"])))
        }
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageManagerDidChangeLanguage")
}
