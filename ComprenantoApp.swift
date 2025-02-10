import SwiftUI
import SwiftData
import os.log

@main
struct ComprenantoApp: App {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    private let log = Logger(subsystem: "com.comprenanto", category: "App")
    private let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: ComprenantoSchema.schema,
                configurations: ComprenantoSchema.configurations
            )
            log.info("Successfully initialized ModelContainer")
        } catch {
            log.error("Failed to create ModelContainer: \(error.localizedDescription)")
            fatalError("Database initialization failed")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, modelContainer.mainContext)
                .environmentObject(permissionManager)
                .environmentObject(settingsManager)
                .onAppear {
                    checkRequiredPermissions()
                }
        }
    }
    
    private func checkRequiredPermissions() {
        Task {
            for permission in [
                PermissionType.microphone,
                PermissionType.camera,
                PermissionType.speechRecognition
            ] {
                _ = await permissionManager.requestPermission(permission)
            }
        }
    }
}
