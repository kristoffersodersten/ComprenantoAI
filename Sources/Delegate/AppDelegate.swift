import UIKit
import os.log

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    let logger = Logger(subsystem: "com.comprenanto", category: "AppDelegate")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupApp()
        return true
    }
    
    private func setupApp() {
        // Configure logging
        logger.info("Application starting...")
        
        // Setup security
        configureSecurity()
        
        // Setup network monitoring
        configureNetworkMonitoring()
        
        // Register for remote notifications
        registerForRemoteNotifications()
    }
    
    private func configureSecurity() {
        // Initialize security manager
        _ = SecurityManager.shared
    }
    
    private func configureNetworkMonitoring() {
        // Initialize network monitoring
        _ = NetworkManager.shared
    }
    
    private func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Failed to register for notifications: \(error.localizedDescription)")
                return
            }
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
