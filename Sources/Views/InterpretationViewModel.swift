import SwiftUI
import Speech
import AVFoundation
import Combine

class InterpretationViewModel: ObservableObject {
    // Published properties for UI updates
    @Published var isSessionActive = false
    @Published var sourceTranscript = ""
    @Published var translation = ""
    @Published var sourceLanguage = "en"
    @Published var targetLanguage = "es"
    @Published var audioLevel: Float = 0.0
    @Published var error: String?
    
    // Audio and speech recognition
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Translation debouncer
    private var translationDebouncer: AnyCancellable?
    private let translationDelay = 0.5 // Seconds to wait before translating
    
    // Services
    private let ttsService: TTSService
    private let translationService: TranslationService
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: sourceLanguage))
        ttsService = TTSService()
        translationService = TranslationService()
        
        setupTranslationDebouncer()
        checkPermissions()
    }
    
    private func setupTranslationDebouncer() {
        translationDebouncer = $sourceTranscript
            .debounce(for: .seconds(translationDelay), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard !text.isEmpty else { return }
                self?.translateText(text)
            }
    }
    
    func startSession() {
        guard !isSessionActive else { return }
        
        do {
            try startAudioSession()
            try startRecognition()
            isSessionActive = true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopSession() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isSessionActive = false
    }
    
    private func startAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startRecognition() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.sourceTranscript = result.bestTranscription.formattedString
            }
            
            if error != nil {
                self.stopSession()
                self.error = error?.localizedDescription
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[Int(i)])
        }
        
        let average = sum / Float(frameLength)
        DispatchQueue.main.async {
            self.audioLevel = average
        }
    }
    
    private func translateText(_ text: String) {
        Task {
            do {
                let translatedText = try await translationService.translate(
                    text: text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                await MainActor.run {
                    self.translation = translatedText
                    synthesizeSpeech(translatedText)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func synthesizeSpeech(_ text: String) {
        Task {
            do {
                try await ttsService.speak(text: text, language: targetLanguage)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    private func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    break
                case .denied, .restricted, .notDetermined:
                    self?.error = "Speech recognition permission is required"
                @unknown default:
                    break
                }
            }
        }
    }
    
    func switchLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        
        // Update speech recognizer for new source language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: sourceLanguage))
        
        // Restart session if active
        if isSessionActive {
            stopSession()
            startSession()
        }
    }
}
