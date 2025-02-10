import CryptoKit
import Foundation
import os.log

enum EncryptionError: Error {
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case keyGenerationFailed(Error)
    case invalidKey
    case invalidData
    case keyDerivationFailed
    case keyRotationFailed
}

actor EncryptionManager {
    static let shared = EncryptionManager()
    
    // Core properties
    private let log = Logger(subsystem: "com.comprenanto", category: "Encryption")
    private let keychain: KeychainManager
    
    // Key management
    private var activeKey: SymmetricKey?
    private var keyRotationTimer: Timer?
    
    // Configuration
    private let keyRotationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let saltLength = 32
    private let iterationCount = 100_000
    
    // MARK: - Types
    
    struct EncryptedData {
        let data: Data
        let iv: Data
        let salt: Data
        let timestamp: Date
        
        var combined: Data {
            var result = Data()
            result.append(salt)
            result.append(iv)
            result.append(data)
            return result
        }
    }
    
    struct EncryptionConfiguration {
        let algorithm: EncryptionAlgorithm
        let keySize: SymmetricKeySize
        let useKeyRotation: Bool
        
        static let standard = EncryptionConfiguration(
            algorithm: .aesGCM,
            keySize: .bits256,
            useKeyRotation: true
        )
    }
    
    enum EncryptionAlgorithm {
        case aesGCM
        case chaCha20
    }
    
    enum SymmetricKeySize {
        case bits128
        case bits192
        case bits256
        
        var bitCount: Int {
            switch self {
            case .bits128: return 128
            case .bits192: return 192
            case .bits256: return 256
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        self.keychain = KeychainManager.shared
        setupKeyRotation()
    }
    
    // MARK: - Public Methods
    
    func encrypt(
        _ data: Data,
        using config: EncryptionConfiguration = .standard
    ) async throws -> EncryptedData {
        guard !data.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        let key = try await getOrGenerateKey(size: config.keySize)
        let salt = generateSalt()
        let iv = generateIV()
        
        do {
            let sealedBox = try AES.GCM.seal(
                data,
                using: key,
                nonce: try AES.GCM.Nonce(data: iv),
                authenticating: salt
            )
            
            guard let encrypted = sealedBox.ciphertext else {
                throw EncryptionError.encryptionFailed(NSError(domain: "Encryption", code: -1))
            }
            
            return EncryptedData(
                data: encrypted,
                iv: iv,
                salt: salt,
                timestamp: Date()
            )
        } catch {
            log.error("Encryption failed: \(error.localizedDescription)")
            throw EncryptionError.encryptionFailed(error)
        }
    }
    
    func decrypt(
        _ encryptedData: EncryptedData,
        using config: EncryptionConfiguration = .standard
    ) async throws -> Data {
        let key = try await getOrGenerateKey(size: config.keySize)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: try AES.GCM.Nonce(data: encryptedData.iv),
                ciphertext: encryptedData.data,
                tag: Data() // Tag is included in ciphertext for GCM
            )
            
            return try AES.GCM.open(sealedBox, using: key, authenticating: encryptedData.salt)
        } catch {
            log.error("Decryption failed: \(error.localizedDescription)")
            throw EncryptionError.decryptionFailed(error)
        }
    }
    
    func rotateKey() async throws {
        let newKey = generateKey(size: .bits256)
        
        // Re-encrypt sensitive data with new key
        try await reencryptSensitiveData(using: newKey)
        
        // Store new key
        try await storeKey(newKey)
        activeKey = newKey
        
        log.info("Key rotation completed successfully")
    }
    
    // MARK: - Private Methods
    
    private func setupKeyRotation() {
        guard keyRotationTimer == nil else { return }
        
        keyRotationTimer = Timer.scheduledTimer(withTimeInterval: keyRotationInterval, repeats: true) { [weak self] _ in
            Task {
                try await self?.rotateKey()
            }
        }
    }
    
    private func getOrGenerateKey(size: SymmetricKeySize) async throws -> SymmetricKey {
        if let key = activeKey { return key }
        
        // Try to load existing key
        if let storedKey: SymmetricKey = try? await keychain.load(for: "encryptionKey") {
            activeKey = storedKey
            return storedKey
        }
        
        // Generate new key
        let newKey = generateKey(size: size)
        try await storeKey(newKey)
        activeKey = newKey
        return newKey
    }
    
    private func generateKey(size: SymmetricKeySize) -> SymmetricKey {
        SymmetricKey(size: SymmetricKeySize(rawValue: size.bitCount) ?? .bits256)
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: saltLength)
        _ = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, buffer.baseAddress!)
        }
        return salt
    }
    
    private func generateIV() -> Data {
        var iv = Data(count: 12) // Standard size for AES-GCM
        _ = iv.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 12, buffer.baseAddress!)
        }
        return iv
    }
    
    private func storeKey(_ key: SymmetricKey) async throws {
        try await keychain.save(key, for: "encryptionKey")
    }
    
    private func reencryptSensitiveData(using newKey: SymmetricKey) async throws {
        // Implement re-encryption of sensitive data
        // This would involve:
        // 1. Loading all encrypted data
        // 2. Decrypting with old key
        // 3. Encrypting with new key
        // 4. Storing updated data
    }
}

// MARK: - Convenience Extensions

extension EncryptionManager {
    func encryptString(_ string: String) async throws -> EncryptedData {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        return try await encrypt(data)
    }
    
    func decryptString(from encrypted: EncryptedData) async throws -> String {
        let data = try await decrypt(encrypted)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed(NSError(domain: "Decryption", code: -1))
        }
        return string
    }
}

// MARK: - Usage Example

extension EncryptionManager {
    static func example() async {
        let manager = EncryptionManager.shared
        
        do {
            // Encrypt sensitive data
            let sensitiveText = "Confidential interpretation data"
            let encrypted = try await manager.encryptString(sensitiveText)
            
            // Decrypt data
            let decrypted = try await manager.decryptString(from: encrypted)
            print("Decrypted: \(decrypted)")
            
            // Rotate encryption key
            try await manager.rotateKey()
        } catch {
            print("Encryption error: \(error)")
        }
    }
}
