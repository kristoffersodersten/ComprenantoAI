import SwiftUI
import Combine

class CallViewModel: ObservableObject {
    @Published var isCallActive = false
    @Published var isVideoCall = false
    @Published var isTranslationEnabled = false
    @Published var isMuted = false
    @Published var contactName = "John Doe"
    @Published var callStatus = "Calling..."
    @Published var originalSpeech = ""
    @Published var translatedSpeech = ""
    
    private var callService: CallService
    private var translationService: TranslationService
    
    init(callService: CallService = CallService(),
         translationService: TranslationService = TranslationService()) {
        self.callService = callService
        self.translationService = translationService
    }
    
    func startAudioCall() {
        isVideoCall = false
        startCall()
    }
    
    func startVideoCall() {
        isVideoCall = true
        startCall()
    }
    
    private func startCall() {
        isCallActive = true
        callStatus = "Connected"
        
        // Simulera inkommande tal
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.receiveSpeech()
        }
    }
    
    func endCall() {
        isCallActive = false
        callStatus = "Call ended"
    }
    
    func toggleMute() {
        isMuted.toggle()
    }
    
    func toggleSpeaker() {
        // Implementera högtalarfunktionalitet
    }
    
    private func receiveSpeech() {
        Task {
            let speech = await callService.receiveSpeech()
            if isTranslationEnabled {
                let translation = await translationService.translate(speech, to: "targetLanguage")
                await MainActor.run {
                    self.originalSpeech = speech
                    self.translatedSpeech = translation
                }
            } else {
                await MainActor.run {
                    self.originalSpeech = speech
                    self.translatedSpeech = ""
                }
            }
        }
    }
}

class CallService {
    func receiveSpeech() async -> String {
        // Simulera mottaget tal
        return "This is a simulated speech input."
    }
}
