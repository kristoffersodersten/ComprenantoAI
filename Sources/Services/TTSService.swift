import Foundation
import AVFoundation
import Combine
import os.log

enum TTSError: Error, LocalizedError {
    case speechGenerationFailed(Error)
    case invalidVoice
    case audioPlaybackFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .speechGenerationFailed(let error):
            return "Failed to generate speech: \(error.localizedDescription)"
        case .invalidVoice:
            return "Invalid voice selected"
        case .audioPlaybackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"
        }
    }
}

actor TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    private let log = Logger(subsystem: "com.comprenanto", category: "TTSService")
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Types
    
    struct TTSRequest: Codable {
        let text: String
        let voice: String
        let language: String?
    }
    
    struct TTSResponse: Codable {
        let audioURL: URL
        let duration: TimeInterval
    }
    
    struct Voice: Codable, Identifiable {
        let id: String
        let name: String
        let language: String
        let gender: String
    }
    
    // MARK: - Public Methods
    
    func generateSpeech(request: TTSRequest) async throws -> TTSResponse {
        guard let voice = AVSpeechSynthesisVoice(identifier: request.voice) else {
            throw TTSError.invalidVoice
        }
        
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = voice
        
        if let language = request.language {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let audioFileURL = try generateAudioFile(for: utterance)
                let duration = try getAudioDuration(for: audioFileURL)
                
                continuation.resume(returning: TTSResponse(audioURL: audioFileURL, duration: duration))
            } catch {
                continuation.resume(throwing: TTSError.speechGenerationFailed(error))
            }
        }
    }
    
    func getAvailableVoices() -> [Voice] {
        AVSpeechSynthesisVoice.speechVoices().map { avVoice in
            Voice(
                id: avVoice.identifier,
                name: avVoice.name,
                language: avVoice.language,
                gender: avVoice.gender == .male ? "Male" : "Female"
            )
        }
    }
    
    func playAudio(url: URL) async throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            throw TTSError.audioPlaybackFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func generateAudioFile(for utterance: AVSpeechUtterance) throws -> URL {
        let audioEngine = AVAudioEngine()
        let mixer = audioEngine.mainMixerNode
        let output = audioEngine.outputNode
        let format = output.inputFormat(forBus: 0)
        
        audioEngine.attach(synthesizer.outputNode)
        audioEngine.connect(synthesizer.outputNode, to: mixer, format: nil)
        audioEngine.connect(mixer, to: output, format: nil)
        
        let maxFrames = AVAudioFrameCount(4 * 44100)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames)!
        
        mixer.installTap(onBus: 0, bufferSize: maxFrames, format: format) { (buffer, _) in
            let audioFile = try? AVAudioFile(forWriting: self.getTemporaryAudioFileURL(), settings: format.settings)
            try? audioFile?.write(from: buffer)
        }
        
        do {
            try audioEngine.start()
            synthesizer.speak(utterance)
            synthesizer.wait(until: .finished)
            audioEngine.stop()
        } catch {
            audioEngine.stop()
            throw error
        }
        
        return getTemporaryAudioFileURL()
    }
    
    private func getTemporaryAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(UUID().uuidString + ".wav")
    }
    
    private func getAudioDuration(for url: URL) throws -> TimeInterval {
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        return audioPlayer.duration
    }
}

// MARK: - SwiftUI Views

struct TTSView: View {
    @StateObject private var viewModel = TTSViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter text to speak", text: $viewModel.text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Picker("Voice", selection: $viewModel.selectedVoice) {
                ForEach(viewModel.availableVoices) { voice in
                    Text(voice.name).tag(voice.id)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Button(action: {
                viewModel.generateSpeech()
            }) {
                Text("Generate Speech")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isGenerating)
            
            if viewModel.isGenerating {
                ProgressView("Generating speech...")
            }
            
            if let audioURL = viewModel.audioURL {
                Button(action: {
                    viewModel.playAudio()
                }) {
                    Text("Play Audio")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
}

class TTSViewModel: ObservableObject {
    @Published var text = ""
    @Published var selectedVoice = ""
    @Published var availableVoices: [TTSService.Voice] = []
    @Published var isGenerating = false
    @Published var audioURL: URL?
    @Published var error: String?
    
    private let ttsService = TTSService()
    
    init() {
        Task {
            await loadVoices()
        }
    }
    
    @MainActor
    func loadVoices() async {
        availableVoices = await ttsService.getAvailableVoices()
        if let firstVoice = availableVoices.first {
            selectedVoice = firstVoice.id
        }
    }
    
    func generateSpeech() {
        guard !text.isEmpty else { return }
        
        isGenerating = true
        error = nil
        
        Task {
            do {
                let request = TTSService.TTSRequest(text: text, voice: selectedVoice, language: nil)
                let response = try await ttsService.generateSpeech(request: request)
                
                await MainActor.run {
                    self.audioURL = response.audioURL
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    func playAudio() {
        guard let audioURL = audioURL else { return }
        
        Task {
            do {
                try await ttsService.playAudio(url: audioURL)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    TTSView()
}
