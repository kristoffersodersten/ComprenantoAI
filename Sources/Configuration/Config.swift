import Foundation

struct Config {
    // API Settings
    let openaiApiKey: String
    let apiBaseUrl: String
    
    // Security Settings
    let secretKey: String
    let aesSecretKey: String
    
    // OpenAI API URLs
    let openaiTtsUrl: String
    let openaiTranslationUrl: String
    
    // App Settings
    let logLevel: LogLevel
    let environment: Environment
    
    enum LogLevel: String {
        case debug, info, warning, error
    }
    
    enum Environment: String {
        case development, staging, production
    }
    
    static let shared = Config.loadFromEnvironment()
    
    private static func loadFromEnvironment() -> Config {
        // Load from environment or configuration file
        return Config(
            openaiApiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "",
            apiBaseUrl: ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.openai.com/v1",
            secretKey: ProcessInfo.processInfo.environment["SECRET_KEY"] ?? "",
            aesSecretKey: ProcessInfo.processInfo.environment["AES_SECRET_KEY"] ?? "",
            openaiTtsUrl: ProcessInfo.processInfo.environment["OPENAI_TTS_URL"] ?? "https://api.openai.com/v1/audio/speech",
            openaiTranslationUrl: ProcessInfo.processInfo.environment["OPENAI_TRANSLATION_URL"] ?? "https://api.openai.com/v1/chat/completions",
            logLevel: LogLevel(rawValue: ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info") ?? .info,
            environment: Environment(rawValue: ProcessInfo.processInfo.environment["ENVIRONMENT"] ?? "development") ?? .development
        )
    }
}
