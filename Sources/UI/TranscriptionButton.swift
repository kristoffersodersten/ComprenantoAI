import SwiftUI

struct TranscriptionButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(isRecording ? "Stop" : "Start Transcription")
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isRecording ? Color.red : (isEnabled ? Color.blue : Color.gray)
                )
                .cornerRadius(10)
                .animation(.easeInOut, value: isRecording)
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        TranscriptionButton(isRecording: false, isEnabled: true) {}
        TranscriptionButton(isRecording: true, isEnabled: true) {}
        TranscriptionButton(isRecording: false, isEnabled: false) {}
    }
    .padding()
}
