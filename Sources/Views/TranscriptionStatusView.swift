import SwiftUI

struct TranscriptionStatusView: View {
    let isRecording: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isRecording ? Color.red : Color.gray)
                .frame(width: 12, height: 12)
                .pulseAnimation(isAnimating: isRecording)
            
            Text(isRecording ? "Recording..." : "Ready to record")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        TranscriptionStatusView(isRecording: false)
        TranscriptionStatusView(isRecording: true)
    }
    .padding()
    .background(Color(.systemGray6))
}
