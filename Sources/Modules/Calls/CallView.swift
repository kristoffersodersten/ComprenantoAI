import SwiftUI

struct CallView: View {
    @StateObject private var viewModel = CallViewModel()
    
    var body: some View {
        VStack {
            CallHeader(viewModel: viewModel)
            
            Spacer()
            
            if viewModel.isCallActive {
                CallContent(viewModel: viewModel)
            } else {
                CallInitiator(viewModel: viewModel)
            }
            
            Spacer()
            
            CallControls(viewModel: viewModel)
        }
        .padding()
        .navigationTitle("Call")
    }
}

struct CallHeader: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        HStack {
            CircularIcon(systemName: "person.crop.circle")
            
            VStack(alignment: .leading) {
                Text(viewModel.contactName)
                    .font(.headline)
                Text(viewModel.callStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("Translation", isOn: $viewModel.isTranslationEnabled)
        }
    }
}

struct CallContent: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        VStack {
            if viewModel.isVideoCall {
                VideoPreviewView()
            } else {
                CircularIcon(systemName: "person.crop.circle")
                    .font(.system(size: 100))
            }
            
            if viewModel.isTranslationEnabled {
                TranslationView(originalText: viewModel.originalSpeech,
                                translatedText: viewModel.translatedSpeech)
            }
        }
    }
}

struct CallInitiator: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            CircularIcon(systemName: "person.crop.circle")
                .font(.system(size: 100))
            
            Text(viewModel.contactName)
                .font(.title)
            
            HStack(spacing: 50) {
                CircularButton(action: viewModel.startAudioCall, systemName: "phone.fill")
                CircularButton(action: viewModel.startVideoCall, systemName: "video.fill")
            }
        }
    }
}

struct CallControls: View {
    @ObservedObject var viewModel: CallViewModel
    
    var body: some View {
        HStack(spacing: 30) {
            CircularButton(action: viewModel.toggleMute, systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
            CircularButton(action: viewModel.endCall, systemName: "phone.down.fill", color: .red)
            CircularButton(action: viewModel.toggleSpeaker, systemName: "speaker.wave.2.fill")
        }
    }
}

struct CircularIcon: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .font(.title)
            .padding()
            .background(Circle().fill(Color.gray.opacity(0.2)))
            .premiumCornerRadius()
    }
}

struct CircularButton: View {
    let action: () -> Void
    let systemName: String
    var color: Color = .blue
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(color))
                .premiumCornerRadius()
        }
    }
}

struct TranslationView: View {
    let originalText: String
    let translatedText: String
    
    var body: some View {
        VStack {
            Text(originalText)
                .font(.body)
                .padding()
                .background(Color.gray.opacity(0.2))
                .premiumCornerRadius()
            
            Text(translatedText)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.2))
                .premiumCornerRadius()
        }
    }
}

struct VideoPreviewView: View {
    var body: some View {
        Color.black
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Image(systemName: "video.slash")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            )
            .premiumCornerRadius()
    }
}
