import Foundation
import CryptoKit
import LocalAuthentication

final class SecurityManager {
    static let shared = SecurityManager()
    
    private let encryptionManager = EncryptionManager()
    private let authenticationManager = AuthenticationManager()
    private let privacyManager = PrivacyManager()
    
    // MARK: - Authentication
    
    func authenticateUser() async throws -> Bool {
        try await authenticationManager.authenticate()
    }
    
    // MARK: - Data Protection
    
    func encryptData(_ data: Data) throws -> EncryptedData {
        try encryptionManager.encrypt(data)
    }
    
    func decryptData(_ encryptedData: EncryptedData) throws -> Data {
        try encryptionManager.decrypt(encryptedData)
    }
    
    // MARK: - Privacy
    
    func sanitizeData(_ data: Data) throws -> Data {
        try privacyManager.sanitize(data)
    }
    
    func checkPrivacyCompliance(for data: Data) throws -> PrivacyReport {
        try privacyManager.checkCompliance(for: data)
    }
}

// MARK: - Authentication Manager

final class AuthenticationManager {
    private let context = LAContext()
    
    func authenticate() async throws -> Bool {
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw SecurityError.biometricsNotAvailable
        }
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access the app"
        )
    }
}

// MARK: - Encryption Manager

final class EncryptionManager {
    private let keychain = KeychainManager()
    
    func encrypt(_ data: Data) throws -> EncryptedData {
        let key = try getOrCreateKey()
        let salt = generateSalt()
        let nonce = try ChaChaPoly.Nonce()
        
        let sealedBox = try ChaChaPoly.seal(data, using: key, nonce: nonce, authenticating: salt)
        
        return EncryptedData(
            data: sealedBox.ciphertext,
            tag: sealedBox.tag,
            nonce: sealedBox.nonce,
            salt: salt
        )
    }
    
    func decrypt(_ encryptedData: EncryptedData) throws -> Data {
        let key = try getOrCreateKey()
        
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: encryptedData.nonce,
            ciphertext: encryptedData.data,
            tag: encryptedData.tag
        )
        
        return try ChaChaPoly.open(sealedBox, using: key, authenticating: encryptedData.salt)
    }
    
    private func getOrCreateKey() throws -> SymmetricKey {
        if let existingKey = try? keychain.readKey() {
            return existingKey
        }
        
        let newKey = SymmetricKey(size: .bits256)
        try keychain.saveKey(newKey)
        return newKey
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        return salt
    }
}

// MARK: - Privacy Manager

final class PrivacyManager {
    private let piiDetector = PIIDetector()
    
    func sanitize(_ data: Data) throws -> Data {
        // Implementera PII-sanering
        return data
    }
    
    func checkCompliance(for data: Data) throws -> PrivacyReport {
        let piiInstances = try piiDetector.detect(in: data)
        return PrivacyReport(
            hasPII: !piiInstances.isEmpty,
            piiTypes: piiInstances.map(\.type),
            recommendations: generateRecommendations(for: piiInstances)
        )
    }
    
    private func generateRecommendations(for piiInstances: [PIIInstance]) -> [String] {
        // Implementera rekommendationsgenerering
        return []
    }
}

// MARK: - Supporting Types

struct EncryptedData {
    let data: Data
    let tag: Data
    let nonce: ChaChaPoly.Nonce
    let salt: Data
}

struct PIIInstance {
    let type: PIIType
    let range: Range<Int>
    let confidence: Double
}

enum PIIType {
    case email
    case phoneNumber
    case creditCard
    case address
    case name
}

struct PrivacyReport {
    let hasPII: Bool
    let piiTypes: [PIIType]
    let recommendations: [String]
}

enum SecurityError: Error {
    case biometricsNotAvailable
    case authenticationFailed
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
}
