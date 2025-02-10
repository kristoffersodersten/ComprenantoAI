import UserNotifications
import Combine
import os.log

enum NotificationError: Error {
    case permissionDenied
    case schedulingFailed(Error)
    case invalidContent
    case systemError(Error)
}

enum NotificationType {
    case interpretationReady
    case interpretationComplete
    case languageDetected(String)
    case qualityAlert(QualityIssue)
    case systemStatus(SystemStatus)
    
    enum QualityIssue {
        case lowConfidence
        case highLatency
        case poorAudioQuality
    }
    
    enum SystemStatus {
        case serverConnected
        case serverDisconnected
        case lowBattery
        case highCPUUsage
    }
}

protocol NotificationManagerDelegate: AnyObject {
    func notificationPermissionUpdated(granted: Bool)
    func notificationReceived(_ notification: InterpretationNotification)
    func notificationActionTriggered(_ action: NotificationAction)
}

actor PushNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()
    
    // Core properties
    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.comprenanto", category: "Notifications")
    private var delegate: NotificationManagerDelegate?
    
    // State management
    private var isPermissionGranted = false
    private var scheduledNotifications: Set<String> = []
    
    // Publishers
    let notificationPublisher = PassthroughSubject<InterpretationNotification, Never>()
    let permissionPublisher = PassthroughSubject<Bool, Never>()
    
    // MARK: - Types
    
    struct InterpretationNotification: Identifiable {
        let id: String
        let type: NotificationType
        let title: String
        let body: String
        let timestamp: Date
        let metadata: [String: Any]?
        var isRead: Bool = false
    }
    
    struct NotificationAction: Identifiable {
        let id: String
        let title: String
        let type: ActionType
        
        enum ActionType {
            case restart
            case pause
            case resume
            case settings
            case dismiss
        }
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotificationHandling()
    }
    
    // MARK: - Public Methods
    
    func setDelegate(_ delegate: NotificationManagerDelegate) {
        self.delegate = delegate
    }
    
    func requestPermissions() async throws {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
            isPermissionGranted = try await center.requestAuthorization(options: options)
            
            await MainActor.run {
                permissionPublisher.send(isPermissionGranted)
                delegate?.notificationPermissionUpdated(granted: isPermissionGranted)
            }
            
            if isPermissionGranted {
                log.info("Notification permissions granted")
                await registerNotificationCategories()
            } else {
                log.warning("Notification permissions denied")
                throw NotificationError.permissionDenied
            }
        } catch {
            log.error("Failed to request notification permissions: \(error.localizedDescription)")
            throw NotificationError.systemError(error)
        }
    }
    
    func scheduleInterpretationNotification(
        type: NotificationType,
        title: String,
        body: String,
        metadata: [String: Any]? = nil,
        trigger: UNNotificationTrigger? = nil
    ) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        if let metadata = metadata {
            content.userInfo = metadata
        }
        
        // Add category based on notification type
        content.categoryIdentifier = notificationCategory(for: type)
        
        // Create unique identifier
        let identifier = "com.comprenanto.notification.\(UUID().uuidString)"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            scheduledNotifications.insert(identifier)
            log.info("Scheduled notification: \(identifier)")
        } catch {
            log.error("Failed to schedule notification: \(error.localizedDescription)")
            throw NotificationError.schedulingFailed(error)
        }
    }
    
    func removeScheduledNotification(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledNotifications.remove(identifier)
        log.info("Removed scheduled notification: \(identifier)")
    }
    
    func removeAllNotifications() async {
        center.removeAllPendingNotificationRequests()
        scheduledNotifications.removeAll()
        log.info("Removed all scheduled notifications")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task {
            await handleNotificationPresentation(notification)
            completionHandler([.banner, .sound])
        }
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationHandling() {
        center.delegate = self
    }
    
    private func registerNotificationCategories() async {
        let interpretationCategory = UNNotificationCategory(
            identifier: "interpretation",
            actions: [
                UNNotificationAction(
                    identifier: "pause",
                    title: "Pause",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "resume",
                    title: "Resume",
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        let qualityCategory = UNNotificationCategory(
            identifier: "quality",
            actions: [
                UNNotificationAction(
                    identifier: "settings",
                    title: "Settings",
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        await center.setNotificationCategories([interpretationCategory, qualityCategory])
    }
    
    private func notificationCategory(for type: NotificationType) -> String {
        switch type {
        case .interpretationReady, .interpretationComplete:
            return "interpretation"
        case .qualityAlert:
            return "quality"
        default:
            return "default"
        }
    }
    
    private func handleNotificationPresentation(_ notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        let interpretationNotification = InterpretationNotification(
            id: notification.request.identifier,
            type: notificationType(from: userInfo),
            title: notification.request.content.title,
            body: notification.request.content.body,
            timestamp: notification.date,
            metadata: userInfo
        )
        
        await MainActor.run {
            notificationPublisher.send(interpretationNotification)
            delegate?.notificationReceived(interpretationNotification)
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let action = NotificationAction(
            id: response.notification.request.identifier,
            title: response.actionIdentifier,
            type: actionType(from: response.actionIdentifier)
        )
        
        await MainActor.run {
            delegate?.notificationActionTriggered(action)
        }
    }
    
    private func notificationType(from userInfo: [AnyHashable: Any]) -> NotificationType {
        // Implement notification type extraction from userInfo
        return .interpretationReady
    }
    
    private func actionType(from identifier: String) -> NotificationAction.ActionType {
        switch identifier {
        case "pause": return .pause
        case "resume": return .resume
        case "settings": return .settings
        case UNNotificationDefaultActionIdentifier: return .dismiss
        default: return .dismiss
        }
    }
}
