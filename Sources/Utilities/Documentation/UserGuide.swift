import SwiftUI

struct UserGuideView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Comprenanto User Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()

                    Text("Welcome to Comprenanto! This guide will help you navigate and use the app effectively.")
                        .font(.title2)
                        .padding(.bottom, 10)

                    Section(header: Text("Getting Started")) {
                        Text("1. **Launch the App:** Open the Comprenanto app on your device.")
                        Text("2. **Grant Permissions:** Allow Comprenanto access to your microphone and camera (if needed).")
                        Text("3. **Choose a Module:** Select a module from the main menu (Transcription, Translation, Messaging, etc.).")
                    }

                    Section(header: Text("Transcription Module")) {
                        Text("1. **Start Recording:** Tap the record button to begin transcribing your speech.")
                        Text("2. **View Transcription:** The transcribed text will appear in real-time.")
                        Text("3. **Copy to Clipboard:** The transcribed text is automatically copied to your clipboard.")
                        Image("transcription_screenshot") // Replace with actual screenshot
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }

                    Section(header: Text("Translation Module")) {
                        Text("1. **Enter Text:** Type the text you want to translate.")
                        Text("2. **Select Language:** Choose the source and target languages.")
                        Text("3. **View Translation:** The translated text will appear below.")
                        Image("translation_screenshot") // Replace with actual screenshot
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }

                    Section(header: Text("Messaging Module")) {
                        // Add instructions for the messaging module
                    }

                    Section(header: Text("Call Modules (Voice & Video)")) {
                        // Add instructions for voice and video call modules
                    }

                    Section(header: Text("Settings")) {
                        // Add instructions for accessing and using settings
                    }

                    Text("For more detailed information, please visit our website: [Your Website Link Here]")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
                .padding()
            }
            .navigationTitle("User Guide")
        }
    }
}
