import SwiftUI

@main
struct ComprenantoApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var securityManager = SecurityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
                .environmentObject(settingsManager)
                .environmentObject(securityManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        Task {
            await appCoordinator.initialize()
            await UserAdaptationManager.shared.initialize()
            ModuleCoordinator.shared.setupModuleInterconnections()
            PerformanceOptimizer.shared.startMonitoring()
        }
    }
}

class AppCoordinator: ObservableObject {
    @Published var currentModule: ModuleType = .home
    @Published var isAuthenticated = false
    
    private let securityManager = SecurityManager.shared
    private let userAdaptationManager = UserAdaptationManager.shared
    
    func initialize() async {
        do {
            isAuthenticated = try await securityManager.authenticateUser()
            if isAuthenticated {
                await loadUserPreferences()
            }
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
        }
    }
    
    func switchToModule(_ module: ModuleType) {
        currentModule = module
        userAdaptationManager.trackUserAction(UserAction(type: .moduleSwitch, module: module))
    }
    
    private func loadUserPreferences() async {
        // Load and apply user preferences
    }
}
