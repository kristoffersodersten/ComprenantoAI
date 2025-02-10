import Speech
import AVFoundation
import Combine
import os.log

enum VoiceControlError: Error {
    case authorizationFailed
    case recognitionFailed(Error)
    case audioEngineError(Error)
    case unavailable
}

protocol VoiceControlManagerDelegate: AnyObject {
    func voiceControlDidReceiveTranscription(_ transcription: String)
    func voiceControlDidFailWithError(_ error: VoiceControlError)
}

class VoiceControlManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "VoiceControlManager")
    weak var delegate: VoiceControlManagerDelegate?
    @Published var isListening = false

    init(locale: Locale = Locale(identifier: "en-US")) { // Allow specifying locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        self.speechRecognizer?.delegate = self
        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.log.info("Speech recognition authorized.")
                case .denied:
                    self.log.error("Speech recognition denied.")
                    self.delegate?.voiceControlDidFailWithError(.authorizationFailed)
                case .restricted:
                    self.log.error("Speech recognition restricted.")
                    self.delegate?.voiceControlDidFailWithError(.authorizationFailed)
                case .notDetermined:
                    self.log.info("Speech recognition not determined.")
                @unknown default:
                    self.log.error("Unknown speech recognition authorization status.")
                    self.delegate?.voiceControlDidFailWithError(.authorizationFailed)
                }
            }
        }
    }

    func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable, !isListening else {
            throw VoiceControlError.unavailable
        }
        isListening = true
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a recognition request") }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.delegate?.voiceControlDidReceiveTranscription(transcription)
                }
            }
            if let error = error {
                self.log.error("Recognition failed: \(error)")
                DispatchQueue.main.async {
                    self.delegate?.voiceControlDidFailWithError(.recognitionFailed(error))
                }
            }
            self.stopListening()
        }

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        do {
            try audioEngine.start()
        } catch {
            log.error("audioEngine failed to start: \(error)")
            throw VoiceControlError.audioEngineError(error)
        }
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
    }

    func stopListening() {
        isListening = false
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            log.info("Speech recognition is available.")
        } else {
            log.error("Speech recognition is unavailable.")
            delegate?.voiceControlDidFailWithError(.unavailable)
        }
    }
}
