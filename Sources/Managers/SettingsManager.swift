import Foundation
import Combine
import os.log

enum SettingsError: Error {
    case saveFailed(String)
    case loadFailed(String)
    case invalidValue(String)
    case encodingFailed(Error)
    case decodingFailed(Error)
}

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Core properties
    private let storage: UserDefaults
    private let log = Logger(subsystem: "com.comprenanto", category: "Settings")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Settings
    
    // Language Settings
    @Published var sourceLanguage: Language {
        didSet { save(sourceLanguage, for: .sourceLanguage) }
    }
    
    @Published var targetLanguage: Language {
        didSet { save(targetLanguage, for: .targetLanguage) }
    }
    
    // Interpretation Settings
    @Published var interpretationSettings: InterpretationSettings {
        didSet { save(interpretationSettings, for: .interpretation) }
    }
    
    // Audio Settings
    @Published var audioSettings: AudioSettings {
        didSet { save(audioSettings, for: .audio) }
    }
    
    // Interface Settings
    @Published var interfaceSettings: InterfaceSettings {
        didSet { save(interfaceSettings, for: .interface) }
    }
    
    // MARK: - Types
    
    struct Language: Codable, Equatable {
        let code: String
        let name: String
        let isInstalled: Bool
        
        static let english = Language(code: "en", name: "English", isInstalled: true)
    }
    
    struct InterpretationSettings: Codable {
        var autoStart: Bool
        var continuousMode: Bool
        var retainContext: Bool
        var maxLatency: TimeInterval
        var confidenceThreshold: Double
        var useServerProcessing: Bool
        
        static let `default` = InterpretationSettings(
            autoStart: true,
            continuousMode: true,
            retainContext: true,
            maxLatency: 0.3,
            confidenceThreshold: 0.8,
            useServerProcessing: true
        )
    }
    
    struct AudioSettings: Codable {
        var inputGain: Double
        var noiseSuppression: Bool
        var echoCancellation: Bool
        var preferredVoice: String
        var speechRate: Double
        var useCustomVoice: Bool
        
        static let `default` = AudioSettings(
            inputGain: 1.0,
            noiseSuppression: true,
            echoCancellation: true,
            preferredVoice: "alloy",
            speechRate: 1.0,
            useCustomVoice: false
        )
    }
    
    struct InterfaceSettings: Codable {
        var theme: Theme
        var showTranscription: Bool
        var showConfidenceScores: Bool
        var enableHaptics: Bool
        var showTutorial: Bool
        
        enum Theme: String, Codable {
            case system, light, dark
        }
        
        static let `default` = InterfaceSettings(
            theme: .system,
            showTranscription: true,
            showConfidenceScores: false,
            enableHaptics: true,
            showTutorial: true
        )
    }
    
    enum SettingKey: String {
        case sourceLanguage
        case targetLanguage
        case interpretation
        case audio
        case interface
    }
    
    // MARK: - Initialization
    
    private init(storage: UserDefaults = .standard) {
        self.storage = storage
        
        // Initialize with default or stored values
        self.sourceLanguage = load(.sourceLanguage) ?? .english
        self.targetLanguage = load(.targetLanguage) ?? .english
        self.interpretationSettings = load(.interpretation) ?? .default
        self.audioSettings = load(.audio) ?? .default
        self.interfaceSettings = load(.interface) ?? .default
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func resetToDefaults() {
        sourceLanguage = .english
        targetLanguage = .english
        interpretationSettings = .default
        audioSettings = .default
        interfaceSettings = .default
    }
    
    func export() throws -> Data {
        let settings = ExportedSettings(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            interpretation: interpretationSettings,
            audio: audioSettings,
            interface: interfaceSettings,
            exportDate: Date()
        )
        return try JSONEncoder().encode(settings)
    }
    
    func `import`(from data: Data) throws {
        let settings = try JSONDecoder().decode(ExportedSettings.self, from: data)
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
        interpretationSettings = settings.interpretation
        audioSettings = settings.audio
        interfaceSettings = settings.interface
    }
    
    // MARK: - Private Methods
    
    private func save<T: Encodable>(_ value: T, for key: SettingKey) {
        do {
            let data = try JSONEncoder().encode(value)
            storage.set(data, forKey: key.rawValue)
            log.info("Saved setting: \(key.rawValue)")
        } catch {
            log.error("Failed to save setting: \(key.rawValue), error: \(error.localizedDescription)")
        }
    }
    
    private func load<T: Decodable>(_ key: SettingKey) -> T? {
        guard let data = storage.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            log.info("Loaded setting: \(key.rawValue)")
            return value
        } catch {
            log.error("Failed to load setting: \(key.rawValue), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

private struct ExportedSettings: Codable {
    let sourceLanguage: SettingsManager.Language
    let targetLanguage: SettingsManager.Language
    let interpretation: SettingsManager.InterpretationSettings
    let audio: SettingsManager.AudioSettings
    let interface: SettingsManager.InterfaceSettings
    let exportDate: Date
}

// MARK: - Usage Example

extension SettingsManager {
    static func example() {
        let settings = SettingsManager.shared
        
        // Configure interpretation settings
        settings.interpretationSettings = InterpretationSettings(
            autoStart: true,
            continuousMode: true,
            retainContext: true,
            maxLatency: 0.2,
            confidenceThreshold: 0.9,
            useServerProcessing: true
        )
        
        // Configure audio settings
        settings.audioSettings = AudioSettings(
            inputGain: 1.2,
            noiseSuppression: true,
            echoCancellation: true,
            preferredVoice: "alloy",
            speechRate: 1.1,
            useCustomVoice: false
        )
        
        // Export settings
        if let data = try? settings.export() {
            print("Settings exported successfully")
            
            // Import settings
            try? settings.import(from: data)
        }
    }
}
