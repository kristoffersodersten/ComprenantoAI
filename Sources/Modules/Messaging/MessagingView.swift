import SwiftUI

struct MessagingView: View {
    @StateObject private var viewModel = MessagingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            MessageList(messages: viewModel.messages)
            
            TranslationPreview(viewModel: viewModel)
            
            MessageInputBar(viewModel: viewModel)
        }
        .navigationTitle("Messages")
        .premiumCornerRadius()
    }
}

struct MessageList: View {
    let messages: [Message]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showTranslation = false
    
    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading) {
            Text(message.text)
                .padding()
                .background(message.isOutgoing ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .premiumCornerRadius()
            
            if showTranslation {
                Text(message.translation ?? "")
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .premiumCornerRadius()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
        .onTapGesture {
            withAnimation {
                showTranslation.toggle()
            }
        }
    }
}

struct TranslationPreview: View {
    @ObservedObject var viewModel: MessagingViewModel
    
    var body: some View {
        VStack {
            if viewModel.isTranslating {
                TranslationAnimationView(
                    originalText: viewModel.currentMessage,
                    translatedText: viewModel.translatedMessage,
                    retranslatedText: viewModel.retranslatedMessage
                )
            }
            
            if let culturalSuggestion = viewModel.culturalSuggestion {
                CulturalSuggestionView(suggestion: culturalSuggestion)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .premiumCornerRadius()
    }
}

struct TranslationAnimationView: View {
    let originalText: String
    let translatedText: String
    let retranslatedText: String
    
    @State private var currentPhase = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(originalText)
                .opacity(currentPhase == 0 ? 1 : 0.5)
            
            Text(translatedText)
                .opacity(currentPhase == 1 ? 1 : 0.5)
            
            Text(retranslatedText)
                .opacity(currentPhase == 2 ? 1 : 0.5)
        }
        .onAppear {
            animateTranslation()
        }
    }
    
    private func animateTranslation() {
        withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
            currentPhase = (currentPhase + 1) % 3
        }
    }
}

struct CulturalSuggestionView: View {
    let suggestion: String
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb")
                .foregroundColor(.yellow)
            
            Text(suggestion)
                .font(.footnote)
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .premiumCornerRadius()
    }
}

struct MessageInputBar: View {
    @ObservedObject var viewModel: MessagingViewModel
    
    var body: some View {
        HStack {
            TextField("Type a message", text: $viewModel.currentMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
        }
        .padding()
    }
}
