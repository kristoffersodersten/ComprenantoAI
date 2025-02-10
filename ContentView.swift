import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: TranscriptionView()) {
                    Label("Transcription", systemImage: "waveform")
                }
                NavigationLink(destination: TranslationView()) {
                    Label("Translation", systemImage: "globe")
                }
                NavigationLink(destination: MessagingView()) {
                    Label("Messaging", systemImage: "message.fill")
                }
                NavigationLink(destination: CallView()) {
                    Label("Calls", systemImage: "phone.fill")
                }
            }
            .navigationTitle("Comprenanto")
        }
    }
}

struct TranscriptionView: View {
    var body: some View {
        Text("Transcription Module")
    }
}

struct TranslationView: View {
    var body: some View {
        Text("Translation Module")
    }
}

struct MessagingView: View {
    var body: some View {
        Text("Messaging Module")
    }
}

struct CallView: View {
    var body: some View {
        Text("Calls Module")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
