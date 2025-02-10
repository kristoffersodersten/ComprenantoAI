import SwiftUI

struct MessagingView: View {
    @StateObject private var viewModel = MessagingViewModel()
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            VStack {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id)
                        }
                    }
                }
                
                // Message input
                HStack {
                    TextField("Message", text: $viewModel.messageText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isSending)
                    
                    Button(action: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .disabled(viewModel.messageText.isEmpty || viewModel.isSending)
                }
                .padding()
            }
            .navigationTitle("Messages")
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading) {
            HStack {
                if message.isOutgoing {
                    Spacer()
                }
                
                VStack(alignment: message.isOutgoing ? .trailing : .leading) {
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(message.isOutgoing ? Color.blue : Color(.systemGray5))
                        .foregroundColor(message.isOutgoing ? .white : .primary)
                        .cornerRadius(16)
                    
                    if let translation = message.translation {
                        Text(translation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    }
                }
                
                if !message.isOutgoing {
                    Spacer()
                }
            }
        }
    }
}

struct MessagingView_Previews: PreviewProvider {
    static var previews: some View {
        MessagingView()
            .environmentObject(SettingsManager.shared)
    }
}
