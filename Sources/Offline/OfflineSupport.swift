import Foundation
import CoreData
import os.log

enum OfflineStorageError: Error {
    case contextNotAvailable
    case encodingFailed(Error)
    case decodingFailed(Error)
    case saveFailed(Error)
    case loadFailed(Error)
    case entityNotFound
    case invalidData
}

class OfflineSupport {
    static let shared = OfflineSupport()
    
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.comprenanto", category: "OfflineSupport")
    
    // Queue for synchronizing data access
    private let queue = DispatchQueue(label: "com.comprenanto.offline", qos: .userInitiated)
    
    // MARK: - Models
    
    struct InterpretationSession: Codable {
        let id: UUID
        let sourceLanguage: String
        let targetLanguage: String
        let timestamp: Date
        var segments: [InterpretationSegment]
    }
    
    struct InterpretationSegment: Codable {
        let id: UUID
        let sourceText: String
        let translatedText: String
        let timestamp: Date
        let duration: TimeInterval
    }
    
    // MARK: - Initialization
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "ComprenantoData")
        
        // Configure persistent store options
        let storeDescription = persistentContainer.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.log.error("Failed to load persistent store: \(error.localizedDescription)")
                fatalError("Persistent store loading failed")
            }
        }
        
        context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        
        backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    func saveSession(_ session: InterpretationSession) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                do {
                    let encodedData = try JSONEncoder().encode(session)
                    let entity = OfflineSessionEntity(context: self.backgroundContext)
                    entity.id = session.id
                    entity.data = encodedData
                    entity.timestamp = session.timestamp
                    entity.sourceLanguage = session.sourceLanguage
                    entity.targetLanguage = session.targetLanguage
                    
                    try self.backgroundContext.save()
                    self.log.info("Saved session: \(session.id)")
                    continuation.resume()
                } catch {
                    self.log.error("Failed to save session: \(error.localizedDescription)")
                    continuation.resume(throwing: OfflineStorageError.saveFailed(error))
                }
            }
        }
    }
    
    func loadSession(id: UUID) async throws -> InterpretationSession {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                let fetchRequest = OfflineSessionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                do {
                    guard let entity = try self.backgroundContext.fetch(fetchRequest).first else {
                        throw OfflineStorageError.entityNotFound
                    }
                    
                    guard let data = entity.data else {
                        throw OfflineStorageError.invalidData
                    }
                    
                    let session = try JSONDecoder().decode(InterpretationSession.self, from: data)
                    self.log.info("Loaded session: \(id)")
                    continuation.resume(returning: session)
                } catch {
                    self.log.error("Failed to load session: \(error.localizedDescription)")
                    continuation.resume(throwing: OfflineStorageError.loadFailed(error))
                }
            }
        }
    }
    
    func loadRecentSessions(limit: Int = 10) async throws -> [InterpretationSession] {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                let fetchRequest = OfflineSessionEntity.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                fetchRequest.fetchLimit = limit
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    var sessions: [InterpretationSession] = []
                    
                    for entity in entities {
                        if let data = entity.data,
                           let session = try? JSONDecoder().decode(InterpretationSession.self, from: data) {
                            sessions.append(session)
                        }
                    }
                    
                    self.log.info("Loaded \(sessions.count) recent sessions")
                    continuation.resume(returning: sessions)
                } catch {
                    self.log.error("Failed to load recent sessions: \(error.localizedDescription)")
                    continuation.resume(throwing: OfflineStorageError.loadFailed(error))
                }
            }
        }
    }
    
    func deleteSession(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                let fetchRequest = OfflineSessionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    entities.forEach(self.backgroundContext.delete)
                    try self.backgroundContext.save()
                    
                    self.log.info("Deleted session: \(id)")
                    continuation.resume()
                } catch {
                    self.log.error("Failed to delete session: \(error.localizedDescription)")
                    continuation.resume(throwing: OfflineStorageError.saveFailed(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context !== self.context else {
            return
        }
        
        self.context.perform {
            self.context.mergeChanges(fromContextDidSave: notification)
        }
    }
}

// MARK: - CoreData Entities

@objc(OfflineSessionEntity)
class OfflineSessionEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var data: Data?
    @NSManaged var timestamp: Date
    @NSManaged var sourceLanguage: String
    @NSManaged var targetLanguage: String
}

extension OfflineSessionEntity {
    static func fetchRequest() -> NSFetchRequest<OfflineSessionEntity> {
        return NSFetchRequest<OfflineSessionEntity>(entityName: "OfflineSessionEntity")
    }
}
