import Speech
import AVFoundation
import Combine

enum TranscriptionError: Error {
    case authorizationDenied
    case notAvailable
    case recordingFailed(Error)
    case recognitionFailed(Error)
    case audioEngineFailed(Error)
}

class TranscriptionService: NSObject, SFSpeechRecognizerDelegate {
    static let shared = TranscriptionService()
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var transcriptionSubject = PassthroughSubject<String, Error>()
    var transcriptionPublisher: AnyPublisher<String, Error> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    override private init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    func requestAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized else {
            throw TranscriptionError.authorizationDenied
        }
    }
    
    func startTranscribing() async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.recognitionFailed(NSError(domain: "", code: -1))
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                self?.transcriptionSubject.send(completion: .failure(TranscriptionError.recognitionFailed(error)))
                return
            }
            
            if let result = result {
                self?.transcriptionSubject.send(result.bestTranscription.formattedString)
            }
        }
        
        // Configure audio
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        try audioEngine.start()
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
