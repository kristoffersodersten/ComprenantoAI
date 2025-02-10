import SwiftUI
import Speech
import Combine
import os.log

enum TranscriptionError: Error {
    case notAuthorized
    case recognitionRequestCreationFailed
    case audioEngineFailed(Error)
    case recognitionFailed(Error)
}

@MainActor
class TranscriptionViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var isTranscribing = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var detectedLanguage: String?
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published private(set) var error: TranscriptionError?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let log = Logger(subsystem: "com.comprenanto.viewmodel", category: "Transcription")
    
    private var languageDetectionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
        checkAuthorizationStatus()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() async {
        authorizationStatus = await SFSpeechRecognizer.requestAuthorization()
    }
    
    func startTranscription() async throws {
        guard !isTranscribing else {
            log.warning("Transcription is already in progress.")
            return
        }
        
        guard authorizationStatus == .authorized else {
            log.error("Speech recognition not authorized.")
            throw TranscriptionError.notAuthorized
        }
        
        isTranscribing = true
        transcribedText = ""
        error = nil
        
        do {
            try await setupAudioSession()
            try startAudioEngine()
            try startRecognitionTask()
        } catch {
            isTranscribing = false
            self.error = error as? TranscriptionError ?? .audioEngineFailed(error)
            throw self.error!
        }
    }
    
    func stopTranscription() {
        guard isTranscribing else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isTranscribing = false
        recognitionRequest = nil
        recognitionTask = nil
        
        log.info("Transcription stopped.")
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorizationStatus() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    private func setupBindings() {
        $transcribedText
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.detectLanguage(for: text)
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try await audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try await audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startRecognitionTask() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.recognitionRequestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                
                if result.isFinal {
                    self.stopTranscription()
                }
            }
            
            if let error = error {
                self.log.error("Recognition error: \(error.localizedDescription)")
                self.error = .recognitionFailed(error)
                self.stopTranscription()
            }
        }
    }
    
    private func detectLanguage(for text: String) {
        languageDetectionTask?.cancel()
        
        languageDetectionTask = Task {
            do {
                let languageCode = try await NLLanguageRecognizer.dominantLanguage(for: text)
                self.detectedLanguage = languageCode?.rawValue
            } catch {
                log.error("Language detection failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension TranscriptionViewModel: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        log.info("Speech recognizer availability changed: \(available)")
    }
}

// MARK: - Preview Support

extension TranscriptionViewModel {
    static var preview: TranscriptionViewModel {
        let viewModel = TranscriptionViewModel()
        viewModel.transcribedText = "This is a sample transcription."
        viewModel.detectedLanguage = "en"
        return viewModel
    }
}
