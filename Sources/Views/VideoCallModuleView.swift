import SwiftUI
import WebRTC

struct VideoCallModuleView: View {
    @ObservedObject var callManager: CallManager
    @State private var isCallActive = false
    @State private var callStatusMessage = "Ready to call"
    @State private var isCameraOn = true
    @State private var isMicrophoneOn = true
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            Text(callStatusMessage)
                .font(.headline)
                .padding()

            HStack {
                Button(action: toggleCall) {
                    Text(isCallActive ? "End Call" : "Start Video Call")
                        .padding()
                        .background(isCallActive ? .red : .blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(callManager.isCalling)

                Toggle(isOn: $isCameraOn) {
                    Text("Camera")
                }
                .disabled(!isCallActive)
                .onChange(of: isCameraOn) { newValue in
                    callManager.setCameraEnabled(newValue)
                }

                Toggle(isOn: $isMicrophoneOn) {
                    Text("Microphone")
                }
                .disabled(!isCallActive)
                .onChange(of: isMicrophoneOn) { newValue in
                    callManager.setMicrophoneEnabled(newValue)
                }
            }
            .padding()

            if isCallActive {
                VideoView(rtcView: callManager.remoteVideoView)
                    .frame(width: 300, height: 300)
            }
        }
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Call Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            callManager.delegate = CallManagerDelegate(callStatusMessage: $callStatusMessage, showAlert: showAlert)
        }
    }

    func toggleCall() {
        if isCallActive {
            callManager.stopCall()
            isCallActive = false
            callStatusMessage = "Ready to call"
        } else {
            Task {
                do {
                    try await callManager.startVideoCall()
                    isCallActive = true
                    callStatusMessage = "Call active"
                } catch {
                    showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}

class CallManagerDelegate: NSObject, CallManagerDelegateProtocol {
    @Binding var callStatusMessage: String
    let showAlert: (String) -> Void

    init(callStatusMessage: Binding<String>, showAlert: @escaping (String) -> Void) {
        self._callStatusMessage = callStatusMessage
        self.showAlert = showAlert
    }

    func callStatusChanged(status: String) {
        callStatusMessage = status
    }

    func callFailed(error: Error) {
        showAlert(message: error.localizedDescription)
    }
}

protocol CallManagerDelegateProtocol {
    func callStatusChanged(status: String)
    func callFailed(error: Error)
}
