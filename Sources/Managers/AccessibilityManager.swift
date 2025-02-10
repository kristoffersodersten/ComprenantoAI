import SwiftUI
import Speech
import AVFoundation
import os.log
import CoreHaptics // Import CoreHaptics for advanced haptics
enum AccessibilityManagerError: Error {
    case speechRecognitionAuthorizationFailed
    case speechRecognitionFailed(Error)
    case audioEngineError(Error)
    case hapticEngineError(Error)
}

class AccessibilityManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var textSize: CGFloat = 16
    @Published var hapticIntensity: CGFloat = 0.5
    @Published var isColorBlindModeEnabled = false
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "AccessibilityManager")
    private let hapticEngine: CHHapticEngine?

    init(locale: Locale = Locale(identifier: "en-US")) { // Allow specifying locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.hapticEngine = try? CHHapticEngine()
        super.init()
        self.speechRecognizer?.delegate = self
        self.audioEngine.prepare()
        do {
            try hapticEngine?.start()
        } catch {
            log.error("Haptic engine failed to start: \(error)")
        }
        checkAuthorizationStatus()
    }

    func adjustTextSize(to size: CGFloat) {
        textSize = size
    }

    func adjustHapticIntensity(to intensity: CGFloat) {
        hapticIntensity = intensity
    }

    func toggleColorBlindMode() {
        isColorBlindModeEnabled.toggle()
    }

    private func checkAuthorizationStatus() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.log.info("Speech recognition authorized.")
                case .denied:
                    self.log.error("Speech recognition denied.")
                case .restricted:
                    self.log.error("Speech recognition restricted.")
                case .notDetermined:
                    self.log.info("Speech recognition not determined.")
                @unknown default:
                    self.log.error("Unknown speech recognition authorization status.")
                }
            }
        }
    }

    func startListening(completion: @escaping (Result<String, AccessibilityManagerError>) -> Void) throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw AccessibilityManagerError.speechRecognitionAuthorizationFailed
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a recognition request") }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                completion(.success(transcription))
            }
            if let error = error {
                self.log.error("Recognition failed: \(error)")
                completion(.failure(.speechRecognitionFailed(error)))
            }
            self.stopListening()
        }

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        do {
            try audioEngine.start()
        } catch {
            log.error("audioEngine failed to start: \(error)")
            throw AccessibilityManagerError.audioEngineError(error)
        }
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }

    func audioEngineConfigurationChange(_ engine: AVAudioEngine) {
        // Handle audio engine configuration changes if needed
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            log.info("Speech recognition is available.")
        } else {
            log.error("Speech recognition is unavailable.")
        }
    }

    func playHapticFeedback() {
        guard let engine = hapticEngine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            log.error("Haptic feedback failed: \(error)")
        }
    }
}
