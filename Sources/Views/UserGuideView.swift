import SwiftUI

struct UserGuideView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    welcomeSection
                    gettingStartedSection
                    transcriptionSection
                    translationSection
                    messagingSection
                    callModulesSection
                    settingsSection
                    supportSection
                }
                .padding()
            }
            .navigationTitle("User Guide")
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comprenanto User Guide")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Welcome to Comprenanto! This guide will help you navigate and use the app effectively.")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
        }
    }
    
    private var gettingStartedSection: some View {
        GuideSection(title: "Getting Started") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Launch the App: Open the Comprenanto app on your device.")
                GuideStep(number: 2, text: "Grant Permissions: Allow Comprenanto access to your microphone and camera (if needed).")
                GuideStep(number: 3, text: "Choose a Module: Select a module from the main menu (Transcription, Translation, Messaging, etc.).")
            }
        }
    }
    
    private var transcriptionSection: some View {
        GuideSection(title: "Transcription Module") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Start Recording: Tap the record button to begin transcribing your speech.")
                GuideStep(number: 2, text: "View Transcription: The transcribed text will appear in real-time.")
                GuideStep(number: 3, text: "Copy to Clipboard: The transcribed text is automatically copied to your clipboard.")
                
                Image("transcription_screenshot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
        }
    }
    
    private var translationSection: some View {
        GuideSection(title: "Translation Module") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Enter Text: Type the text you want to translate.")
                GuideStep(number: 2, text: "Select Language: Choose the source and target languages.")
                GuideStep(number: 3, text: "View Translation: The translated text will appear below.")
                
                Image("translation_screenshot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
        }
    }
    
    private var messagingSection: some View {
        GuideSection(title: "Messaging Module") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Start Chat: Select a contact or start a new conversation.")
                GuideStep(number: 2, text: "Real-time Translation: Messages are automatically translated.")
                GuideStep(number: 3, text: "Voice Messages: Record and send voice messages with translation.")
                GuideStep(number: 4, text: "Share Media: Send images and files with translated captions.")
            }
        }
    }
    
    private var callModulesSection: some View {
        GuideSection(title: "Call Modules (Voice & Video)") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Start Call: Choose between voice or video call.")
                GuideStep(number: 2, text: "Live Translation: Speech is translated in real-time during calls.")
                GuideStep(number: 3, text: "Quality Settings: Adjust audio and video quality as needed.")
                GuideStep(number: 4, text: "Call Recording: Save translated calls for later reference (optional).")
            }
        }
    }
    
    private var settingsSection: some View {
        GuideSection(title: "Settings") {
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: "Language Preferences: Set your primary and secondary languages.")
                GuideStep(number: 2, text: "Translation Settings: Customize translation behavior and accuracy.")
                GuideStep(number: 3, text: "Privacy Settings: Control data usage and sharing preferences.")
                GuideStep(number: 4, text: "Notifications: Configure alert preferences for messages and calls.")
            }
        }
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "https://comprenanto.com/support")!) {
                Text("For more detailed information, visit our support website")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .underline()
            }
            
            Text("Version 1.0")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
}

struct GuideSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct GuideStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    UserGuideView()
}
