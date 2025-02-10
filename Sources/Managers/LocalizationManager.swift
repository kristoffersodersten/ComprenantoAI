import Foundation
import Combine
import os.log

enum LocalizationError: Error {
    case stringNotFound(String)
    case invalidLanguage(String)
    case resourceMissing(String)
    case bundleError(Error)
    case storageError(Error)
}

actor LocalizationManager {
    static let shared = LocalizationManager()
    
    // Core properties
    private let storage: UserDefaults
    private let log = Logger(subsystem: "com.comprenanto", category: "Localization")
    private let bundle: Bundle
    
    // Publishers
    let languageChangePublisher = PassthroughSubject<Language, Never>()
    
    // State
    @Published private(set) var currentLanguage: Language
    private let fallbackLanguage = Language.english
    
    // MARK: - Types
    
    struct Language: Codable, Equatable, Hashable {
        let code: String
        let name: String
        let region: String?
        let isRTL: Bool
        let supportsVoice: Bool
        
        var identifier: String {
            if let region = region {
                return "\(code)_\(region)"
            }
            return code
        }
        
        static let english = Language(
            code: "en",
            name: "English",
            region: "US",
            isRTL: false,
            supportsVoice: true
        )
    }
    
    struct LocalizedContent {
        let text: String
        let language: Language
        let alternatives: [Language: String]
        let metadata: [String: String]?
    }
    
    // MARK: - Initialization
    
    private init(
        storage: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.storage = storage
        self.bundle = bundle
        
        // Load saved language or use system default
        if let savedLanguage: Language = try? storage.decode(forKey: "currentLanguage") {
            self.currentLanguage = savedLanguage
        } else {
            self.currentLanguage = Self.systemLanguage ?? .english
        }
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func localizedString(
        forKey key: String,
        table: String? = nil,
        interpolation: [String: String] = [:]
    ) async throws -> LocalizedContent {
        // Try current language
        if let content = try? await loadString(
            forKey: key,
            language: currentLanguage,
            table: table
        ) {
            return interpolateContent(content, with: interpolation)
        }
        
        // Try fallback language
        if let content = try? await loadString(
            forKey: key,
            language: fallbackLanguage,
            table: table
        ) {
            return interpolateContent(content, with: interpolation)
        }
        
        throw LocalizationError.stringNotFound(key)
    }
    
    func setLanguage(_ language: Language) async throws {
        // Verify language resources exist
        guard hasLanguageSupport(for: language) else {
            throw LocalizationError.resourceMissing(language.identifier)
        }
        
        // Update language
        currentLanguage = language
        
        // Save preference
        try storage.encode(language, forKey: "currentLanguage")
        
        // Notify observers
        languageChangePublisher.send(language)
        
        log.info("Language changed to: \(language.identifier)")
    }
    
    func availableLanguages() async -> [Language] {
        // Get available language resources
        let availablePaths = bundle.paths(forResourcesOfType: "lproj", inDirectory: nil)
        
        return availablePaths.compactMap { path in
            let languageCode = path.components(separatedBy: "/").last?.replacingOccurrences(of: ".lproj", with: "")
            guard let code = languageCode,
                  let language = try? languageFromCode(code) else {
                return nil
            }
            return language
        }
    }
    
    func translateInterface(
        to language: Language,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await setLanguage(language)
                
                // Reload interface
                await MainActor.run {
                    // Post notification for UI update
                    NotificationCenter.default.post(
                        name: .interfaceLanguageDidChange,
                        object: self,
                        userInfo: ["language": language]
                    )
                }
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadString(
        forKey key: String,
        language: Language,
        table: String?
    ) async throws -> LocalizedContent {
        guard let path = bundle.path(forResource: language.identifier, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            throw LocalizationError.resourceMissing(language.identifier)
        }
        
        let text = languageBundle.localizedString(
            forKey: key,
            value: nil,
            table: table
        )
        
        // Get alternatives
        var alternatives: [Language: String] = [:]
        for altLanguage in await availableLanguages() where altLanguage != language {
            if let altPath = bundle.path(forResource: altLanguage.identifier, ofType: "lproj"),
               let altBundle = Bundle(path: altPath) {
                let altText = altBundle.localizedString(
                    forKey: key,
                    value: nil,
                    table: table
                )
                alternatives[altLanguage] = altText
            }
        }
        
        return LocalizedContent(
            text: text,
            language: language,
            alternatives: alternatives,
            metadata: nil
        )
    }
    
    private func interpolateContent(
        _ content: LocalizedContent,
        with interpolation: [String: String]
    ) -> LocalizedContent {
        var interpolatedText = content.text
        var interpolatedAlternatives = content.alternatives
        
        // Interpolate main text
        for (key, value) in interpolation {
            interpolatedText = interpolatedText.replacingOccurrences(
                of: "{\(key)}",
                with: value
            )
        }
        
        // Interpolate alternatives
        for (language, text) in content.alternatives {
            var interpolatedAltText = text
            for (key, value) in interpolation {
                interpolatedAltText = interpolatedAltText.replacingOccurrences(
                    of: "{\(key)}",
                    with: value
                )
            }
            interpolatedAlternatives[language] = interpolatedAltText
        }
        
        return LocalizedContent(
            text: interpolatedText,
            language: content.language,
            alternatives: interpolatedAlternatives,
            metadata: content.metadata
        )
    }
    
    private func hasLanguageSupport(for language: Language) -> Bool {
        bundle.path(forResource: language.identifier, ofType: "lproj") != nil
    }
    
    private func languageFromCode(_ code: String) throws -> Language {
        guard let locale = Locale(identifier: code) else {
            throw LocalizationError.invalidLanguage(code)
        }
        
        return Language(
            code: code,
            name: locale.localizedString(forLanguageCode: code) ?? code,
            region: locale.region?.identifier,
            isRTL: locale.characterDirection == .rightToLeft,
            supportsVoice: true // Update based on actual voice support
        )
    }
    
    private static var systemLanguage: Language? {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        return try? LocalizationManager.shared.languageFromCode(preferredLanguage)
    }
    
    private func setupObservers() {
        // Monitor system language changes
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                if let systemLanguage = Self.systemLanguage {
                    try? await self?.setLanguage(systemLanguage)
                }
            }
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let interfaceLanguageDidChange = Notification.Name("interfaceLanguageDidChange")
}

extension UserDefaults {
    func encode<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        set(data, forKey: key)
    }
    
    func decode<T: Decodable>(forKey key: String) throws -> T {
        guard let data = data(forKey: key) else {
            throw LocalizationError.storageError(
                NSError(domain: "Storage", code: -1, userInfo: nil)
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Usage Example

extension LocalizationManager {
    static func example() async {
        let manager = LocalizationManager.shared
        
        do {
            // Get localized string with interpolation
            let content = try await manager.localizedString(
                forKey: "welcome_message",
                interpolation: ["name": "John"]
            )
            print("Localized: \(content.text)")
            
            // Change language
            let spanish = Language(
                code: "es",
                name: "Spanish",
                region: "ES",
                isRTL: false,
                supportsVoice: true
            )
            try await manager.setLanguage(spanish)
            
            // Get available languages
            let languages = await manager.availableLanguages()
            print("Available languages: \(languages.map(\.name))")
            
        } catch {
            print("Localization error: \(error)")
        }
    }
}
