import Security
import CryptoKit
import Foundation
import os.log

enum KeychainError: Error {
    case saveFailed(OSStatus, String?)
    case loadFailed(OSStatus, String?)
    case deleteFailed(OSStatus, String?)
    case updateFailed(OSStatus, String?)
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case invalidData
    case accessDenied
}

actor KeychainManager {
    static let shared = KeychainManager()
    
    // Core properties
    private let log = Logger(subsystem: "com.comprenanto", category: "Keychain")
    private let encryptionManager = EncryptionManager.shared
    
    // Configuration
    private let accessGroup: String?
    private let serviceName: String
    private let accessControl: SecAccessControl?
    
    // MARK: - Types
    
    struct KeychainItem: Codable {
        let data: Data
        let metadata: [String: String]?
        let timestamp: Date
        let version: Int
    }
    
    struct KeychainConfiguration {
        let accessibility: CFString
        let accessControl: SecAccessControlCreateFlags
        let synchronizable: Bool
        let requiresBiometrics: Bool
        
        static let standard = KeychainConfiguration(
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            accessControl: .biometryAny,
            synchronizable: false,
            requiresBiometrics: true
        )
    }
    
    // MARK: - Initialization
    
    private init(
        serviceName: String = Bundle.main.bundleIdentifier ?? "com.comprenanto",
        accessGroup: String? = nil,
        configuration: KeychainConfiguration = .standard
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        
        // Create access control
        var error: Unmanaged<CFError>?
        self.accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            configuration.accessibility,
            configuration.accessControl,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            log.error("Failed to create access control: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func save<T: Encodable>(
        _ item: T,
        for key: String,
        configuration: KeychainConfiguration = .standard
    ) async throws {
        do {
            let encodedData = try JSONEncoder().encode(item)
            let encryptedData = try await encryptionManager.encrypt(encodedData)
            
            let keychainItem = KeychainItem(
                data: encryptedData.combined,
                metadata: ["type": String(describing: T.self)],
                timestamp: Date(),
                version: 1
            )
            
            let itemData = try JSONEncoder().encode(keychainItem)
            try await saveToKeychain(itemData, for: key, configuration: configuration)
            
        } catch {
            log.error("Failed to save item: \(error.localizedDescription)")
            throw KeychainError.saveFailed(errSecIO, key)
        }
    }
    
    func load<T: Decodable>(
        for key: String,
        configuration: KeychainConfiguration = .standard
    ) async throws -> T {
        do {
            let itemData = try await loadFromKeychain(key, configuration: configuration)
            let keychainItem = try JSONDecoder().decode(KeychainItem.self, from: itemData)
            
            let encryptedData = EncryptionManager.EncryptedData(
                data: keychainItem.data,
                iv: Data(), // Extract from combined data
                salt: Data(), // Extract from combined data
                timestamp: keychainItem.timestamp
            )
            
            let decryptedData = try await encryptionManager.decrypt(encryptedData)
            return try JSONDecoder().decode(T.self, from: decryptedData)
            
        } catch {
            log.error("Failed to load item: \(error.localizedDescription)")
            throw KeychainError.loadFailed(errSecIO, key)
        }
    }
    
    func delete(
        for key: String,
        configuration: KeychainConfiguration = .standard
    ) async throws {
        let query = baseQuery(for: key, configuration: configuration)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            log.error("Failed to delete item: \(status)")
            throw KeychainError.deleteFailed(status, key)
        }
        
        log.info("Successfully deleted item for key: \(key)")
    }
    
    func containsItem(
        for key: String,
        configuration: KeychainConfiguration = .standard
    ) async -> Bool {
        var query = baseQuery(for: key, configuration: configuration)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Methods
    
    private func saveToKeychain(
        _ data: Data,
        for key: String,
        configuration: KeychainConfiguration
    ) async throws {
        var query = baseQuery(for: key, configuration: configuration)
        query[kSecValueData as String] = data
        
        // Check if item exists
        if await containsItem(for: key, configuration: configuration) {
            try await updateInKeychain(data, for: key, configuration: configuration)
            return
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status, key)
        }
        
        log.info("Successfully saved item for key: \(key)")
    }
    
    private func loadFromKeychain(
        _ key: String,
        configuration: KeychainConfiguration
    ) async throws -> Data {
        var query = baseQuery(for: key, configuration: configuration)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status, key)
        }
        
        return data
    }
    
    private func updateInKeychain(
        _ data: Data,
        for key: String,
        configuration: KeychainConfiguration
    ) async throws {
        let query = baseQuery(for: key, configuration: configuration)
        let updateQuery = [kSecValueData as String: data]
        
        let status = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.updateFailed(status, key)
        }
        
        log.info("Successfully updated item for key: \(key)")
    }
    
    private func baseQuery(
        for key: String,
        configuration: KeychainConfiguration
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: configuration.accessibility,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        }
        
        if configuration.synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        
        return query
    }
}

// MARK: - Convenience Extensions

extension KeychainManager {
    func savePassword(_ password: String, for username: String) async throws {
        let credentials = [
            "password": password,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        try await save(credentials, for: username)
    }
    
    func loadPassword(for username: String) async throws -> String {
        let credentials: [String: String] = try await load(for: username)
        guard let password = credentials["password"] else {
            throw KeychainError.invalidData
        }
        return password
    }
}

// MARK: - Usage Example

extension KeychainManager {
    static func example() async {
        let keychain = KeychainManager.shared
        
        do {
            // Save sensitive data
            let credentials = ["username": "user", "password": "secret"]
            try await keychain.save(
                credentials,
                for: "loginCredentials",
                configuration: .standard
            )
            
            // Load data
            let loaded: [String: String] = try await keychain.load(
                for: "loginCredentials"
            )
            print("Loaded credentials: \(loaded)")
            
            // Delete data
            try await keychain.delete(for: "loginCredentials")
        } catch {
            print("Keychain error: \(error)")
        }
    }
}
