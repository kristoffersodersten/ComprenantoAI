import Foundation
import AVFoundation
import Combine
import os.log

enum TTSError: Error {
    case apiError(Error)
    case invalidResponse(Int)
    case encodingError(Error)
    case networkError(Error)
    case audioError(Error)
    case invalidConfiguration
    case synthesisInProgress
}

actor OpenAITTSManager {
    static let shared = OpenAITTSManager()
    
    // Configuration
    private let apiKey: String
    private let apiBaseUrl: String
    private let session: URLSession
    private let log = Logger(subsystem: "com.comprenanto", category: "TTSManager")
    
    // Audio handling
    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let audioQueue = DispatchQueue(label: "com.comprenanto.tts.audio")
    
    // State management
    private var isSynthesizing = false
    private var currentTask: Task<Void, Error>?
    
    // Synthesis configuration
    private let maxTextLength = 500
    private let defaultVoice = "alloy"
    private let defaultFormat = "mp3"
    
    // Publishers
    let synthesisProgressPublisher = PassthroughSubject<Double, Never>()
    let audioLevelPublisher = PassthroughSubject<Float, Never>()
    
    // MARK: - Types
    
    struct TTSConfiguration {
        let voice: String
        let format: String
        let speed: Float
        let pitch: Float
        let volume: Float
        
        static let `default` = TTSConfiguration(
            voice: "alloy",
            format: "mp3",
            speed: 1.0,
            pitch: 1.0,
            volume: 1.0
        )
    }
    
    struct TTSResult {
        let audioData: Data
        let duration: TimeInterval
        let textLength: Int
        let config: TTSConfiguration
    }
    
    // MARK: - Initialization
    
    private init(
        apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "",
        apiBaseUrl: String = "https://api.openai.com/v1/audio/speech"
    ) {
        self.apiKey = apiKey
        self.apiBaseUrl = apiBaseUrl
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        setupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    func synthesize(
        text: String,
        language: String,
        config: TTSConfiguration = .default
    ) async throws -> TTSResult {
        guard !text.isEmpty else {
            throw TTSError.invalidConfiguration
        }
        
        guard !isSynthesizing else {
            throw TTSError.synthesisInProgress
        }
        
        isSynthesizing = true
        defer { isSynthesizing = false }
        
        // Split long text into chunks
        let chunks = splitText(text, maxLength: maxTextLength)
        var combinedAudioData = Data()
        var totalDuration: TimeInterval = 0
        
        for (index, chunk) in chunks.enumerated() {
            let data = try await synthesizeChunk(
                chunk,
                language: language,
                config: config
            )
            
            combinedAudioData.append(data)
            
            // Update progress
            let progress = Double(index + 1) / Double(chunks.count)
            synthesisProgressPublisher.send(progress)
        }
        
        // Calculate duration from audio data
        if let audioFile = try? AVAudioFile(forReading: createTempFile(with: combinedAudioData)) {
            totalDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        }
        
        return TTSResult(
            audioData: combinedAudioData,
            duration: totalDuration,
            textLength: text.count,
            config: config
        )
    }
    
    func cancelCurrentSynthesis() {
        currentTask?.cancel()
        currentTask = nil
        isSynthesizing = false
    }
    
    // MARK: - Private Methods
    
    private func synthesizeChunk(
        _ text: String,
        language: String,
        config: TTSConfiguration
    ) async throws -> Data {
        guard let url = URL(string: apiBaseUrl) else {
            throw TTSError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": config.voice,
            "response_format": config.format,
            "speed": config.speed
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse(-1)
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw TTSError.invalidResponse(httpResponse.statusCode)
        }
        
        return data
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            log.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func splitText(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }
        
        var chunks: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
            var chunk = String(text[currentIndex..<endIndex])
            
            // Try to split at sentence boundary
            if let lastSentence = chunk.range(of: "[.!?]\\s+", options: .regularExpression, range: chunk.startIndex..<chunk.endIndex, locale: nil) {
                chunk = String(chunk[chunk.startIndex...lastSentence.upperBound])
                currentIndex = text.index(currentIndex, offsetBy: chunk.count)
            } else {
                currentIndex = endIndex
            }
            
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    private func createTempFile(with data: Data) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Convenience Extensions

extension OpenAITTSManager {
    func synthesizeInBackground(
        text: String,
        language: String,
        config: TTSConfiguration = .default
    ) -> AnyPublisher<TTSResult, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TTSError.invalidConfiguration))
                return
            }
            
            Task {
                do {
                    let result = try await self.synthesize(
                        text: text,
                        language: language,
                        config: config
                    )
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
