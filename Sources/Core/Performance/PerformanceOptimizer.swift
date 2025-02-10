import Foundation
import Combine
import SwiftUI

final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let diskCache = DiskCache()
    private let batchProcessor = BatchProcessor()
    private let performanceMonitor = PerformanceMonitor()
    
    private init() {
        setupCache()
        setupPerformanceMonitoring()
    }
    
    func setupCache() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50_000_000 // 50 MB
        
        // Observera minnesvarningar
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    func optimizeMemoryUsage() {
        Task {
            // Rensa gammal cache
            await cleanupOldCache()
            
            // Optimera bildcache
            ImageCache.shared.trim(toCost: 30_000_000) // 30 MB
            
            // Rensa temporära filer
            await cleanupTemporaryFiles()
        }
    }
    
    func startBatchProcessing<T: Processable>(
        items: [T],
        batchSize: Int = 10,
        interval: TimeInterval = 0.1,
        processor: @escaping (T) -> Void
    ) {
        batchProcessor.process(
            items: items,
            batchSize: batchSize,
            interval: interval,
            processor: processor
        )
    }
    
    private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        ImageCache.shared.removeAll()
        
        // Notifiera andra system att frigöra minne
        NotificationCenter.default.post(
            name: .performanceOptimizerDidReceiveMemoryWarning,
            object: nil
        )
    }
}

// MARK: - Batch Processing

final class BatchProcessor {
    private var queue = DispatchQueue(
        label: "com.comprenanto.batchprocessor",
        qos: .userInitiated
    )
    
    func process<T>(
        items: [T],
        batchSize: Int,
        interval: TimeInterval,
        processor: @escaping (T) -> Void
    ) {
        let batches = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }
        
        for (index, batch) in batches.enumerated() {
            queue.asyncAfter(deadline: .now() + interval * Double(index)) {
                batch.forEach(processor)
            }
        }
    }
}

// MARK: - Performance Monitoring

final class PerformanceMonitor {
    private var metrics: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "com.comprenanto.performancemonitor")
    
    func startMeasuring(_ identifier: String) {
        queue.async {
            self.metrics[identifier] = CACurrentMediaTime()
        }
    }
    
    func stopMeasuring(_ identifier: String) -> TimeInterval? {
        queue.sync {
            guard let startTime = metrics[identifier] else { return nil }
            let duration = CACurrentMediaTime() - startTime
            metrics.removeValue(forKey: identifier)
            return duration
        }
    }
    
    func logPerformanceMetrics() {
        queue.async {
            for (identifier, duration) in self.metrics {
                print("Performance metric - \(identifier): \(duration)s")
            }
        }
    }
}

// MARK: - Image Cache

final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.totalCostLimit = 50_000_000 // 50 MB
    }
    
    func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Uppskatta minneskostnad
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
    
    func trim(toCost cost: Int) {
        cache.totalCostLimit = cost
    }
}

// MARK: - Disk Cache

final class DiskCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("com.comprenanto.cache")
        
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    func store(_ data: Data, for key: String) throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try data.write(to: fileURL)
    }
    
    func retrieve(_ key: String) throws -> Data {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        return try Data(contentsOf: fileURL)
    }
    
    func remove(_ key: String) throws {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try fileManager.removeItem(at: fileURL)
    }
    
    func clearCache() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )
        
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Protocols & Extensions

protocol Processable {}

extension Notification.Name {
    static let performanceOptimizerDidReceiveMemoryWarning = Notification.Name("performanceOptimizerDidReceiveMemoryWarning")
}
