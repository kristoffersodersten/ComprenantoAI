import NaturalLanguage
import os.log

enum LanguageDetectionError: Error {
    case languageDetectionFailed(String)
    case lowConfidence(Double)
}

class LanguageDetector {
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "LanguageDetection")
    private let confidenceThreshold: Double = 0.8 // Adjust as needed

    func detectLanguage(for text: String, completion: @escaping (Result<String, LanguageDetectionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tagger = NLTagger(tagSchemes: [.language])
            tagger.string = text
            if let language = tagger.dominantLanguage {
                let languageIdentifier = NLLanguageRecognizer()
                languageIdentifier.processString(text)
                let confidence = languageIdentifier.languageHypotheses(withMaximum: 1)[language] ?? 0.0
                if confidence >= self.confidenceThreshold {
                    self.log.info("Detected language: \(language.rawValue) with confidence: \(confidence)")
                    completion(.success(language.rawValue))
                } else {
                    self.log.error("Language detection confidence too low: \(confidence)")
                    completion(.failure(.lowConfidence(confidence)))
                }
            } else {
                self.log.error("Language detection failed.")
                completion(.failure(.languageDetectionFailed("Language detection failed")))
            }
    func languageProbabilities(
        for text: String,
        maximumHypotheses: Int = 5,
        completion: @escaping (Result<[String: Double], LanguageDetectionError>) -> Void
    ) {
        let languageIdentifier = NLLanguageRecognizer()
        languageIdentifier.processString(text)
        let probabilities = languageIdentifier.languageHypotheses(withMaximum: maximumHypotheses)
        let result = probabilities.reduce(into: [String: Double]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        completion(.success(result))
    }
        }
    }

    func languageProbabilities(
        for text: String,
        maximumHypotheses: Int = 5,
        completion: @escaping (Result<[String: Double], LanguageDetectionError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tagger = NLTagger(tagSchemes: [.language])
            tagger.string = text
            let languageIdentifier = NLLanguageRecognizer()
            languageIdentifier.processString(text)
            let probabilities = languageIdentifier.languageHypotheses(withMaximum: maximumHypotheses)
            let result = probabilities.reduce(into: [String: Double]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
            completion(.success(result))
        }
    }
}
