import CoreData
import CryptoKit
import Combine
import os.log

enum StorageError: Error {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case encryptionFailed(Error)
    case storageFailed(Error)
    case notFound(String)
    case invalidData
    case contextError(Error)
}

actor LocalStorageManager {
    static let shared = LocalStorageManager()
    
    // Core properties
    private let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let encryptionManager: EncryptionManager
    private let log = Logger(subsystem: "com.comprenanto", category: "Storage")
    
    // Publishers
    let storageChangePublisher = PassthroughSubject<StorageChange, Never>()
    
    // MARK: - Types
    
    struct StorageChange {
        let key: String
        let type: ChangeType
        let timestamp: Date
        
        enum ChangeType {
            case created, updated, deleted
        }
    }
    
    struct StorageMetadata: Codable {
        let timestamp: Date
        let version: Int
        let checksum: String
        let type: String
        let encryption: EncryptionInfo
        
        struct EncryptionInfo: Codable {
            let algorithm: String
            let keyId: String
            let iv: Data
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        let container = NSPersistentContainer(name: "ComprenantoData")
        
        // Configure persistent store
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load stores
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        
        self.container = container
        self.backgroundContext = container.newBackgroundContext()
        self.encryptionManager = EncryptionManager.shared
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func save<T: Encodable>(
        _ value: T,
        forKey key: String,
        metadata: [String: String]? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                do {
                    // Encode data
                    let encodedData = try JSONEncoder().encode(value)
                    
                    // Encrypt data
                    let encryptedData = try self.encryptionManager.encrypt(
                        encodedData,
                        using: .standard
                    )
                    
                    // Create or update entity
                    let entity = try self.getOrCreateEntity(forKey: key)
                    entity.key = key
                    entity.data = encryptedData.combined
                    entity.timestamp = Date()
                    entity.metadata = metadata
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    // Notify observers
                    self.storageChangePublisher.send(
                        StorageChange(
                            key: key,
                            type: .updated,
                            timestamp: Date()
                        )
                    )
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.storageFailed(error))
                }
            }
        }
    }
    
    func load<T: Decodable>(forKey key: String) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                do {
                    // Fetch entity
                    let entity = try self.fetchEntity(forKey: key)
                    
                    guard let encryptedData = entity.data else {
                        throw StorageError.invalidData
                    }
                    
                    // Decrypt data
                    let decryptedData = try self.encryptionManager.decrypt(
                        EncryptionManager.EncryptedData(
                            data: encryptedData,
                            iv: Data(), // Extract from metadata
                            salt: Data(), // Extract from metadata
                            timestamp: entity.timestamp ?? Date()
                        )
                    )
                    
                    // Decode data
                    let decodedValue = try JSONDecoder().decode(T.self, from: decryptedData)
                    continuation.resume(returning: decodedValue)
                    
                } catch {
                    continuation.resume(throwing: StorageError.storageFailed(error))
                }
            }
        }
    }
    
    func delete(forKey key: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                do {
                    let entity = try self.fetchEntity(forKey: key)
                    self.backgroundContext.delete(entity)
                    try self.backgroundContext.save()
                    
                    // Notify observers
                    self.storageChangePublisher.send(
                        StorageChange(
                            key: key,
                            type: .deleted,
                            timestamp: Date()
                        )
                    )
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.storageFailed(error))
                }
            }
        }
    }
    
    func clearAll() async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LocalDataEntity.fetchRequest()
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try self.backgroundContext.execute(deleteRequest)
                    try self.backgroundContext.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.storageFailed(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context !== self.backgroundContext else {
            return
        }
        
        backgroundContext.perform {
            self.backgroundContext.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    private func getOrCreateEntity(forKey key: String) throws -> LocalDataEntity {
        let fetchRequest = LocalDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.first ?? LocalDataEntity(context: backgroundContext)
    }
    
    private func fetchEntity(forKey key: String) throws -> LocalDataEntity {
        let fetchRequest = LocalDataEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        
        let results = try backgroundContext.fetch(fetchRequest)
        guard let entity = results.first else {
            throw StorageError.notFound(key)
        }
        
        return entity
    }
}

// MARK: - Core Data Entity

@objc(LocalDataEntity)
class LocalDataEntity: NSManagedObject {
    @NSManaged var key: String
    @NSManaged var data: Data?
    @NSManaged var timestamp: Date?
    @NSManaged var metadata: [String: String]?
}

extension LocalDataEntity {
    static func fetchRequest() -> NSFetchRequest<LocalDataEntity> {
        return NSFetchRequest<LocalDataEntity>(entityName: "LocalDataEntity")
    }
}

// MARK: - Usage Example

extension LocalStorageManager {
    static func example() async {
        let storage = LocalStorageManager.shared
        
        // Store interpretation session
        let session = InterpretationSession(
            id: UUID(),
            sourceLanguage: "en",
            targetLanguage: "es",
            timestamp: Date()
        )
        
        do {
            try await storage.save(
                session,
                forKey: "session_\(session.id)",
                metadata: ["type": "interpretation_session"]
            )
            
            // Load session
            let loaded: InterpretationSession = try await storage.load(
                forKey: "session_\(session.id)"
            )
            print("Loaded session: \(loaded.id)")
            
        } catch {
            print("Storage error: \(error)")
        }
    }
}

struct InterpretationSession: Codable {
    let id: UUID
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
}
