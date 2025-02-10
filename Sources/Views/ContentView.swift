import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            if appCoordinator.isAuthenticated {
                mainContent
            } else {
                AuthenticationView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var mainContent: some View {
        ZStack {
            moduleView
            
            VStack {
                Spacer()
                WaveNavigationHub()
            }
        }
        .navigationTitle(appCoordinator.currentModule.title)
        .navigationBarItems(trailing: settingsButton)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var moduleView: some View {
        switch appCoordinator.currentModule {
        case .home:
            HomeView()
        case .transcription:
            TranscriptionView()
        case .translation:
            TranslationView()
        case .messaging:
            MessagingView()
        case .calls:
            CallView()
        case .videoCall:
            VideoCallView()
        case .textEditor:
            TextEditorView()
        }
    }
    
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gear")
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack {
            Text("Welcome to Comprenanto")
                .font(.largeTitle)
                .padding()
            
            Button(action: authenticate) {
                Text(isAuthenticating ? "Authenticating..." : "Authenticate")
            }
            .disabled(isAuthenticating)
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        Task {
            do {
                appCoordinator.isAuthenticated = try await SecurityManager.shared.authenticateUser()
            } catch {
                print("Authentication failed: \(error.localizedDescription)")
            }
            isAuthenticating = false
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Comprenanto")
                .font(.largeTitle)
            
            Text("Select a module to get started")
                .font(.subheadline)
            
            ForEach(ModuleType.allCases.filter { $0 != .home }, id: \.self) { module in
                Button(action: { appCoordinator.switchToModule(module) }) {
                    HStack {
                        Image(systemName: module.iconName)
                        Text(module.title)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}

extension ModuleType: CaseIterable {
    static var allCases: [ModuleType] = [
        .home, .transcription, .translation, .messaging, .calls, .videoCall, .textEditor
    ]
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .transcription: return "Transcription"
        case .translation: return "Translation"
        case .messaging: return "Messaging"
        case .calls: return "Calls"
        case .videoCall: return "Video Call"
        case .textEditor: return "Text Editor"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .messaging: return "message"
        case .calls: return "phone"
        case .videoCall: return "video"
        case .textEditor: return "doc.text"
        }
    }
}
