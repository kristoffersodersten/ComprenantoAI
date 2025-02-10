import WebRTC
import AVFoundation
import Speech
import Combine
import os.log

enum CallError: Error {
    case webRTCSetup(Error)
    case speechRecognition(Error)
    case translation(Error)
    case audioEngine(Error)
    case authorization(Error)
    case connection(Error)
    case invalidState(String)
}

actor CallManager: NSObject {
    static let shared = CallManager()
    
    // Core components
    private let webRTCClient: WebRTCClient
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private let translationService: TranslationService
    private let ttsService: TTSService
    private let log = Logger(subsystem: "com.comprenanto", category: "CallManager")
    
    // State management
    @Published private(set) var callState: CallState = .idle
    @Published private(set) var audioLevel: Float = 0.0
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Publishers
    let transcriptionPublisher = PassthroughSubject<TranscriptionResult, Never>()
    let translationPublisher = PassthroughSubject<TranslationResult, Never>()
    let callStatePublisher = PassthroughSubject<CallState, Never>()
    
    // Configuration
    private let bufferSize: AVAudioFrameCount = 1024
    private let sampleRate: Double = 44100
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Types
    
    enum CallState: Equatable {
        case idle
        case connecting
        case active(CallSession)
        case error(String)
        case disconnected
    }
    
    struct CallSession: Equatable {
        let id: UUID
        let startTime: Date
        let sourceLanguage: String
        let targetLanguage: String
        var duration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
    }
    
    struct TranscriptionResult {
        let text: String
        let isFinal: Bool
        let confidence: Float
        let timestamp: Date
    }
    
    struct TranslationResult {
        let sourceText: String
        let translatedText: String
        let sourceLanguage: String
        let targetLanguage: String
        let timestamp: Date
    }
    
    // MARK: - Initialization
    
    private override init() {
        self.webRTCClient = WebRTCClient()
        self.speechRecognizer = SFSpeechRecognizer(locale: .current)!
        self.translationService = TranslationService()
        self.ttsService = TTSService()
        
        super.init()
        
        setupAudioSession()
        setupWebRTC()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func startCall(
        sourceLanguage: String,
        targetLanguage: String
    ) async throws {
        guard case .idle = callState else {
            throw CallError.invalidState("Call already in progress")
        }
        
        // Update state
        callState = .connecting
        
        do {
            // Check permissions
            try await checkPermissions()
            
            // Start WebRTC
            try await webRTCClient.start()
            
            // Start speech recognition
            try await startSpeechRecognition(language: sourceLanguage)
            
            // Create call session
            let session = CallSession(
                id: UUID(),
                startTime: Date(),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            // Update state
            callState = .active(session)
            callStatePublisher.send(callState)
            
        } catch {
            callState = .error(error.localizedDescription)
            throw error
        }
    }
    
    func endCall() async {
        // Stop all services
        stopSpeechRecognition()
        await webRTCClient.stop()
        
        // Update state
        callState = .disconnected
        callStatePublisher.send(callState)
    }
    
    func muteAudio(_ muted: Bool) async {
        await webRTCClient.muteAudio(muted)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            log.error("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupWebRTC() {
        webRTCClient.delegate = self
        
        // Handle WebRTC events
        webRTCClient.onIceCandidate = { [weak self] candidate in
            Task {
                try await self?.handleIceCandidate(candidate)
            }
        }
        
        webRTCClient.onTrack = { [weak self] track in
            self?.handleRemoteTrack(track)
        }
    }
    
    private func startSpeechRecognition(language: String) async throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            throw CallError.speechRecognition(NSError(domain: "Unsupported language"))
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw CallError.speechRecognition(NSError(domain: "Failed to create request"))
        }
        
        request.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log.error("Recognition failed: \(error)")
                return
            }
            
            if let result = result {
                let transcription = TranscriptionResult(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal,
                    confidence: result.bestTranscription.segments.last?.confidence ?? 0,
                    timestamp: Date()
                )
                
                self.transcriptionPublisher.send(transcription)
                
                if result.isFinal {
                    Task {
                        await self.handleFinalTranscription(transcription)
                    }
                }
            }
        }
        
        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: recordingFormat
        ) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.processAudioBuffer(buffer)
        }
        
        // Start audio engine
        try audioEngine.start()
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        // Calculate RMS value for audio level
        var sum: Float = 0
        vDSP_meamgv(channelData, 1, &sum, vDSP_Length(buffer.frameLength))
        
        let rms = sqrt(sum / Float(buffer.frameLength))
        audioLevel = rms
    }
    
    private func handleFinalTranscription(_ transcription: TranscriptionResult) async {
        guard case .active(let session) = callState else { return }
        
        do {
            // Translate text
            let translation = try await translationService.translate(
                text: transcription.text,
                from: session.sourceLanguage,
                to: session.targetLanguage
            )
            
            // Send translation result
            let result = TranslationResult(
                sourceText: transcription.text,
                translatedText: translation,
                sourceLanguage: session.sourceLanguage,
                targetLanguage: session.targetLanguage,
                timestamp: Date()
            )
            
            translationPublisher.send(result)
            
            // Synthesize speech
            try await ttsService.speak(
                text: translation,
                language: session.targetLanguage
            )
            
        } catch {
            log.error("Translation failed: \(error)")
        }
    }
    
    private func checkPermissions() async throws {
        // Check speech recognition permission
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            throw CallError.authorization(NSError(domain: "Speech recognition not authorized"))
        }
        
        // Check microphone permission
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            throw CallError.authorization(NSError(domain: "Microphone access denied"))
        }
    }
}

// MARK: - WebRTC Extensions

extension CallManager: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        switch state {
        case .connected:
            callState = .active(CallSession(
                id: UUID(),
                startTime: Date(),
                sourceLanguage: "en",
                targetLanguage: "es"
            ))
        case .disconnected, .failed, .closed:
            callState = .disconnected
        default:
            break
        }
    }
    
    private func handleIceCandidate(_ candidate: RTCIceCandidate) async throws {
        // Send candidate to signaling server
    }
    
    private func handleRemoteTrack(_ track: RTCMediaStreamTrack) {
        // Handle remote audio/video track
    }
}

// MARK: - Usage Example

extension CallManager {
    static func example() async {
        let manager = CallManager.shared
        
        do {
            // Start call
            try await manager.startCall(
                sourceLanguage: "en",
                targetLanguage: "es"
            )
            
            // Monitor transcriptions
            manager.transcriptionPublisher
                .sink { transcription in
                    print("Transcribed: \(transcription.text)")
                }
                .store(in: &manager.cancellables)
            
            // Monitor translations
            manager.translationPublisher
                .sink { translation in
                    print("Translated: \(translation.translatedText)")
                }
                .store(in: &manager.cancellables)
            
            // End call after delay
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            await manager.endCall()
            
        } catch {
            print("Call error: \(error)")
        }
    }
}
