import Foundation

enum TranslationError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
}

class TranslationService {
    static let shared = TranslationService()
    
    private let session: URLSession
    private let apiKey: String
    private let baseURL: String
    
    private init(
        apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "",
        baseURL: String = "https://api.openai.com/v1/chat/completions"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a translator. Translate the following text from \(sourceLanguage) to \(targetLanguage)."
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let translation = message["content"] as? String else {
            throw TranslationError.decodingError(NSError(domain: "", code: -1))
        }
        
        return translation
    }
    
    func detectLanguage(for text: String) async throws -> String {
        // Similar implementation to translate but for language detection
        // You can use the same API with a different prompt
        return "en" // Placeholder
    }
}
