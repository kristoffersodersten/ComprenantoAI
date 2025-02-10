import Foundation
import Speech
import AVFoundation
import os.log

enum TranscriptionError: Error, LocalizedError {
    case fileError(String)
    case transcriptionFailed(Error)
    case languageDetectionFailed(Error)
    case unsupportedFormat
    case invalidAudio
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .fileError(let message):
            return "File error: \(message)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .languageDetectionFailed(let error):
            return "Language detection failed: \(error.localizedDescription)"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .invalidAudio:
            return "Invalid audio data"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        }
    }
}

actor TranscriptionService {
    private let log = Logger(subsystem: "com.comprenanto", category: "TranscriptionService")
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Types
    
    struct TranscriptionResult: Codable {
        let text: String
        let confidence: Float
        let language: String?
        let duration: TimeInterval
        let metadata: [String: String]?
    }
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - Public Methods
    
    func transcribe(
        audioData: Data,
        language: String? = nil,
        prompt: String? = nil
    ) async throws -> TranscriptionResult {
        try await checkAuthorization()
        
        let audioFile = try createTemporaryAudioFile(from: audioData)
        let recognizer = language.flatMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) } ?? speechRecognizer
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.transcriptionFailed(NSError(domain: "Recognizer unavailable", code: -1))
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioFile)
        request.shouldReportPartialResults = false
        
        if let prompt = prompt {
            request.contextualStrings = [prompt]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error))
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: TranscriptionError.invalidAudio)
                    return
                }
                
                let transcriptionResult = TranscriptionResult(
                    text: result.bestTranscription.formattedString,
                    confidence: result.bestTranscription.segments.map(\.confidence).reduce(0, +) / Float(result.bestTranscription.segments.count),
                    language: recognizer.locale.languageCode,
                    duration: result.bestTranscription.segments.last?.duration ?? 0,
                    metadata: [
                        "segments": "\(result.bestTranscription.segments.count)",
                        "isFinal": "\(result.isFinal)"
                    ]
                )
                
                continuation.resume(returning: transcriptionResult)
            }
        }
    }
    
    func detectLanguage(from audioData: Data) async throws -> String {
        try await checkAuthorization()
        
        let audioFile = try createTemporaryAudioFile(from: audioData)
        let recognizer = SFSpeechRecognizer()
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.languageDetectionFailed(NSError(domain: "Recognizer unavailable", code: -1))
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioFile)
        request.shouldReportPartialResults = true
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.languageDetectionFailed(error))
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: recognizer.locale.languageCode ?? "unknown")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized else {
            throw TranscriptionError.authorizationDenied
        }
    }
    
    private func createTemporaryAudioFile(from data: Data) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let audioFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        
        try data.write(to: audioFileURL)
        return audioFileURL
    }
}

// MARK: - SwiftUI Integration

struct AudioTranscriptionView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var transcriptionResult: TranscriptionService.TranscriptionResult?
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var selectedLanguage: String?
    @State private var prompt: String = ""
    
    private let transcriptionService = TranscriptionService()
    
    var body: some View {
        VStack(spacing: 20) {
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if isTranscribing {
                ProgressView("Transcribing...")
            } else if let result = transcriptionResult {
                TranscriptionResultView(result: result)
            }
            
            VStack {
                Picker("Language", selection: $selectedLanguage) {
                    Text("Auto").tag(nil as String?)
                    Text("English").tag("en" as String?)
                    Text("Spanish").tag("es" as String?)
                    // Add more languages as needed
                }
                
                TextField("Prompt (optional)", text: $prompt)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            if audioRecorder.isRecording {
                Button(action: stopRecording) {
                    Text("Stop Recording")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            } else {
                Button(action: startRecording) {
                    Text("Start Recording")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
    
    private func startRecording() {
        do {
            try audioRecorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func stopRecording() {
        audioRecorder.stopRecording()
        transcribeAudio()
    }
    
    private func transcribeAudio() {
        guard let audioData = audioRecorder.audioData else {
            errorMessage = "No audio data available"
            return
        }
        
        isTranscribing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await transcriptionService.transcribe(
                    audioData: audioData,
                    language: selectedLanguage,
                    prompt: prompt.isEmpty ? nil : prompt
                )
                
                await MainActor.run {
                    transcriptionResult = result
                    isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isTranscribing = false
                }
            }
        }
    }
}

struct TranscriptionResultView: View {
    let result: TranscriptionService.TranscriptionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.text)
                .font(.body)
            
            HStack {
                Text("Confidence: \(Int(result.confidence * 100))%")
                Spacer()
                if let language = result.language {
                    Text("Language: \(Locale.current.localizedString(forLanguageCode: language) ?? language)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    AudioTranscriptionView()
}
