import CryptoKit
import Foundation
import os.log

actor InterpretationSecurity {
    static let shared = InterpretationSecurity()
    
    // Core dependencies
    private let encryptionManager = EncryptionManager.shared
    private let log = Logger(subsystem: "com.comprenanto", category: "InterpretationSecurity")
    
    // MARK: - Types
    
    struct SecureInterpretationData {
        let encryptedData: EncryptionManager.EncryptedData
        let metadata: InterpretationMetadata
        let timestamp: Date
    }
    
    struct InterpretationMetadata: Codable {
        let sourceLanguage: String
        let targetLanguage: String
        let contentType: ContentType
        let duration: TimeInterval?
        let checksums: Checksums
        
        enum ContentType: String, Codable {
            case text
            case audio
            case transcription
            case translation
        }
        
        struct Checksums: Codable {
            let sha256: String
            let original: String
        }
    }
    
    // MARK: - Public Methods
    
    func secureTranscription(_ text: String, sourceLanguage: String) async throws -> SecureInterpretationData {
        guard !text.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        // Calculate checksums
        let checksums = calculateChecksums(for: text)
        
        // Create metadata
        let metadata = InterpretationMetadata(
            sourceLanguage: sourceLanguage,
            targetLanguage: sourceLanguage,
            contentType: .transcription,
            duration: nil,
            checksums: checksums
        )
        
        // Encrypt data
        let encryptedData = try await encryptWithMetadata(text, metadata: metadata)
        
        return SecureInterpretationData(
            encryptedData: encryptedData,
            metadata: metadata,
            timestamp: Date()
        )
    }
    
    func secureTranslation(
        _ text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> SecureInterpretationData {
        guard !text.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        // Calculate checksums
        let checksums = calculateChecksums(for: text)
        
        // Create metadata
        let metadata = InterpretationMetadata(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            contentType: .translation,
            duration: nil,
            checksums: checksums
        )
        
        // Encrypt data
        let encryptedData = try await encryptWithMetadata(text, metadata: metadata)
        
        return SecureInterpretationData(
            encryptedData: encryptedData,
            metadata: metadata,
            timestamp: Date()
        )
    }
    
    func secureAudio(
        _ audioData: Data,
        language: String,
        duration: TimeInterval
    ) async throws -> SecureInterpretationData {
        guard !audioData.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        // Calculate checksums
        let checksums = calculateChecksums(for: audioData)
        
        // Create metadata
        let metadata = InterpretationMetadata(
            sourceLanguage: language,
            targetLanguage: language,
            contentType: .audio,
            duration: duration,
            checksums: checksums
        )
        
        // Encrypt data
        let encryptedData = try await encryptionManager.encrypt(
            audioData,
            using: .standard
        )
        
        return SecureInterpretationData(
            encryptedData: encryptedData,
            metadata: metadata,
            timestamp: Date()
        )
    }
    
    func decrypt(_ secureData: SecureInterpretationData) async throws -> Data {
        // Verify checksums before decryption
        let decryptedData = try await encryptionManager.decrypt(secureData.encryptedData)
        let verifiedChecksums = calculateChecksums(for: decryptedData)
        
        guard verifiedChecksums.sha256 == secureData.metadata.checksums.sha256 else {
            throw EncryptionError.invalidData
        }
        
        return decryptedData
    }
    
    // MARK: - Private Methods
    
    private func encryptWithMetadata(_ text: String, metadata: InterpretationMetadata) async throws -> EncryptionManager.EncryptedData {
        guard let data = text.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return try await encryptionManager.encrypt(data, using: .standard)
    }
    
    private func calculateChecksums(for text: String) -> InterpretationMetadata.Checksums {
        guard let data = text.data(using: .utf8) else {
            return .init(sha256: "", original: "")
        }
        return calculateChecksums(for: data)
    }
    
    private func calculateChecksums(for data: Data) -> InterpretationMetadata.Checksums {
        let sha256 = SHA256.hash(data: data)
        let sha256String = sha256.compactMap { String(format: "%02x", $0) }.joined()
        
        return .init(
            sha256: sha256String,
            original: data.base64EncodedString()
        )
    }
}

// MARK: - Usage Example

extension InterpretationSecurity {
    static func example() async {
        let security = InterpretationSecurity.shared
        
        do {
            // Secure transcription
            let transcription = try await security.secureTranscription(
                "Hello, how are you?",
                sourceLanguage: "en"
            )
            
            // Secure translation
            let translation = try await security.secureTranslation(
                "Hello, how are you?",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
            
            // Decrypt data
            let decryptedData = try await security.decrypt(translation)
            if let text = String(data: decryptedData, encoding: .utf8) {
                print("Decrypted: \(text)")
            }
        } catch {
            print("Security error: \(error)")
        }
    }
}
