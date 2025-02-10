import Foundation

class TTSRouter {
    private let ttsService: TTSService
    
    init(ttsService: TTSService = TTSService()) {
        self.ttsService = ttsService
    }
    
    func generateSpeech(request: TTSRequest) async throws -> TTSResponse {
        do {
            return try await ttsService.generateSpeech(request: request)
        } catch {
            throw APIError.internalServerError(error.localizedDescription)
        }
    }
    
    func getVoices() async throws -> [Voice] {
        do {
            return await ttsService.getAvailableVoices()
        } catch {
            throw APIError.internalServerError(error.localizedDescription)
        }
    }
}

enum APIError: Error {
    case internalServerError(String)
}
