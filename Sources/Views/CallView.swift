import SwiftUI
import AVKit

struct CallView: View {
    @StateObject private var viewModel = CallViewModel()
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Call status
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                // Video preview when active
                if viewModel.isCallActive {
                    VideoPreviewView()
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                }
                
                // Audio visualization
                AudioWaveformView(level: viewModel.audioLevel)
                    .frame(height: 60)
                    .padding()
                
                // Call controls
                HStack(spacing: 30) {
                    // Mute button
                    ControlButton(
                        icon: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                        color: viewModel.isMuted ? .red : .blue,
                        action: viewModel.toggleMute,
                        isEnabled: viewModel.isCallActive
                    )
                    
                    // Main call button
                    Button(action: viewModel.toggleCall) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isCallActive ? Color.red : Color.green)
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: viewModel.isCallActive ? "phone.down.fill" : "phone.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Camera button
                    ControlButton(
                        icon: viewModel.isCameraEnabled ? "video.fill" : "video.slash.fill",
                        color: viewModel.isCameraEnabled ? .blue : .red,
                        action: viewModel.toggleCamera,
                        isEnabled: viewModel.isCallActive
                    )
                }
            }
            .padding()
            .navigationTitle("Call")
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
    
    private var statusColor: Color {
        switch viewModel.callState {
        case .active: return .green
        case .error: return .red
        case .connecting: return .orange
        default: return .primary
        }
    }
}

struct VideoPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct AudioWaveformView: View {
    let level: Float
    @State private var samples: [CGFloat] = Array(repeating: 0.2, count: 30)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<30) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: (geometry.size.width - 58) / 30)
                        .frame(height: geometry.size.height * samples[index])
                }
            }
            .onChange(of: level) { newLevel in
                samples.removeFirst()
                samples.append(CGFloat(newLevel))
            }
        }
    }
}

struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isEnabled ? color : .gray)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
        }
        .disabled(!isEnabled)
    }
}

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
            .environmentObject(SettingsManager.shared)
    }
}
