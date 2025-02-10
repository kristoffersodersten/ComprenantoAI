import Foundation
import CoreData
import NaturalLanguage
import os.log

enum DataCollectionError: Error {
    case analysisError(String)
    case storageError(Error)
    case invalidData(String)
}

class DataCollectionManager: ObservableObject {
    static let shared = DataCollectionManager()
    private let queue = DispatchQueue(label: "com.comprenanto.analytics", qos: .utility)
    private let log = Logger(subsystem: "com.comprenanto", category: "DataCollection")
    
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    @Published private(set) var isCollecting = false
    @Published private(set) var stats = InterpretationStats()
    
    // MARK: - Models
    
    struct InterpretationStats: Codable {
        var totalSessions = 0
        var totalDuration: TimeInterval = 0
        var languagePairs: Set<LanguagePair> = []
        var averageLatency: TimeInterval = 0
        var lastUpdated = Date()
        
        struct LanguagePair: Codable, Hashable {
            let source: String
            let target: String
        }
    }
    
    struct InterpretationSample: Codable {
        let id = UUID()
        let sourceText: String
        let translatedText: String
        let sourceLanguage: String
        let targetLanguage: String
        let latency: TimeInterval
        let accuracy: Float
        let timestamp: Date
        let context: InterpretationContext
    }
    
    struct InterpretationContext: Codable {
        let sessionId: UUID
        let speakingRate: Float
        let noiseLevel: Float
        let sentiment: Float
        let isQuestion: Bool
        let isPause: Bool
    }
    
    // MARK: - Initialization
    
    init() {
        persistentContainer = NSPersistentContainer(name: "ComprenantoData")
        context = persistentContainer.viewContext
        
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.log.error("CoreData initialization failed: \(error.localizedDescription)")
            }
        }
        
        setupAutosave()
    }
    
    // MARK: - Public Methods
    
    func startSession() {
        guard !isCollecting else { return }
        isCollecting = true
        stats.totalSessions += 1
        log.info("Started interpretation session")
    }
    
    func endSession() {
        guard isCollecting else { return }
        isCollecting = false
        saveStats()
        log.info("Ended interpretation session")
    }
    
    func collectInterpretationSample(
        source: String,
        translation: String,
        sourceLanguage: String,
        targetLanguage: String,
        latency: TimeInterval,
        context: InterpretationContext
    ) {
        guard isCollecting else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let accuracy = try self.calculateAccuracy(source: source, translation: translation)
                
                let sample = InterpretationSample(
                    sourceText: source,
                    translatedText: translation,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    latency: latency,
                    accuracy: accuracy,
                    timestamp: Date(),
                    context: context
                )
                
                try self.storeSample(sample)
                self.updateStats(with: sample)
                
                self.log.info("Collected interpretation sample: \(sourceLanguage) -> \(targetLanguage)")
            } catch {
                self.log.error("Failed to collect sample: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateAccuracy(source: String, translation: String) throws -> Float {
        // Implement your accuracy calculation logic here
        // This could involve comparing key terms, sentence structure, etc.
        // For now, returning a placeholder value
        return 0.8
    }
    
    private func storeSample(_ sample: InterpretationSample) throws {
        let entity = InterpretationEntity(context: context)
        entity.id = sample.id
        entity.sourceText = sample.sourceText
        entity.translatedText = sample.translatedText
        entity.sourceLanguage = sample.sourceLanguage
        entity.targetLanguage = sample.targetLanguage
        entity.latency = sample.latency
        entity.accuracy = sample.accuracy
        entity.timestamp = sample.timestamp
        entity.sessionId = sample.context.sessionId
        entity.speakingRate = sample.context.speakingRate
        entity.noiseLevel = sample.context.noiseLevel
        entity.sentiment = sample.context.sentiment
        entity.isQuestion = sample.context.isQuestion
        entity.isPause = sample.context.isPause
        
        try context.save()
    }
    
    private func updateStats(with sample: InterpretationSample) {
        let languagePair = InterpretationStats.LanguagePair(
            source: sample.sourceLanguage,
            target: sample.targetLanguage
        )
        
        stats.languagePairs.insert(languagePair)
        stats.averageLatency = (stats.averageLatency * Double(stats.totalSessions - 1) + sample.latency) / Double(stats.totalSessions)
        stats.lastUpdated = Date()
    }
    
    private func setupAutosave() {
        // Autosave every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveStats()
        }
    }
    
    private func saveStats() {
        do {
            try context.save()
            log.info("Stats saved successfully")
        } catch {
            log.error("Failed to save stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - CoreData Entities

class InterpretationEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sourceText: String
    @NSManaged var translatedText: String
    @NSManaged var sourceLanguage: String
    @NSManaged var targetLanguage: String
    @NSManaged var latency: TimeInterval
    @NSManaged var accuracy: Float
    @NSManaged var timestamp: Date
    @NSManaged var sessionId: UUID
    @NSManaged var speakingRate: Float
    @NSManaged var noiseLevel: Float
    @NSManaged var sentiment: Float
    @NSManaged var isQuestion: Bool
    @NSManaged var isPause: Bool
}
