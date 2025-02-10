import AVFoundation
import Foundation
import os.log

enum TTSManagerError: Error {
    case apiError(Error)
    case invalidResponse(Int)
    case encodingError(Error)
    case audioPlayerError(Error)
    case networkError(Error)
    case missingData
}

class TTSManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private let apiKey: String
    private let apiBaseUrl: String
    private let session: URLSession
    private var audioPlayer: AVAudioPlayer?
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "TTSManager")

    init(apiKey: String, apiBaseUrl: String = "https://api.openai.com/v1/audio/speech") {
        self.apiKey = apiKey
        self.apiBaseUrl = apiBaseUrl
        self.session = URLSession(configuration: .default)
    }

    func speak(
        text: String,
        language: String,
        voice: String = "alloy",
        format: String = "mp3",
        completion: @escaping (Result<Data, TTSManagerError>) -> Void
    ) {
        guard let url = URL(string: apiBaseUrl) else {
            completion(.failure(.apiError(NSError(domain: "InvalidURL", code: -1, userInfo: nil))))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice,
            "response_format": format
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            log.error("Error encoding payload: \(error)")
            completion(.failure(.encodingError(error)))
            return
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                self.log.error("Network error: \(error)")
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.log.error("Invalid response")
                completion(.failure(.invalidResponse(-1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                self.log.error("API request failed with status code: \(httpResponse.statusCode)")
                completion(.failure(.invalidResponse(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                self.log.error("Missing data in response")
                completion(.failure(.missingData))
                return
            }

            completion(.success(data))
        }
        task.resume()
    }

    func playAudio(data: Data, completion: @escaping (Result<Void, TTSManagerError>) -> Void) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            completion(.success(()))
        } catch {
            log.error("Error playing audio: \(error)")
            completion(.failure(.audioPlayerError(error)))
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        log.info("Audio playback finished.")
        audioPlayer = nil // Release audio player
    }
}
