import Foundation
import Combine

final class ModuleCoordinator {
    static let shared = ModuleCoordinator()
    
    private var modules: [Module] = []
    private var moduleConnections: [ModuleConnection] = []
    private let contextBridge = ContextBridge()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Module Management
    
    func registerModule(_ module: Module) {
        modules.append(module)
        setupModuleConnections(for: module)
        synchronizeSettings(for: module)
    }
    
    func connectModules(_ moduleA: Module, _ moduleB: Module) {
        let connection = ModuleConnection(moduleA: moduleA, moduleB: moduleB)
        moduleConnections.append(connection)
        
        // Sätt upp delad kontext
        contextBridge.establishConnection(between: moduleA, and: moduleB)
    }
    
    // MARK: - Context Sharing
    
    func shareContext(from sourceModule: Module, to targetModule: Module, context: ModuleContext) {
        contextBridge.shareContext(from: sourceModule, to: targetModule, context: context)
    }
    
    // MARK: - Settings Synchronization
    
    private func synchronizeSettings(for module: Module) {
        module.settingsPublisher
            .sink { [weak self] settings in
                self?.propagateSettings(settings, from: module)
            }
            .store(in: &cancellables)
    }
    
    private func propagateSettings(_ settings: ModuleSettings, from source: Module) {
        let connectedModules = findConnectedModules(for: source)
        connectedModules.forEach { module in
            module.updateSettings(settings)
        }
    }
    
    private func findConnectedModules(for module: Module) -> [Module] {
        moduleConnections
            .filter { $0.involves(module) }
            .flatMap { $0.modules(excluding: module) }
    }
}

// MARK: - Module Protocol and Types

protocol Module: AnyObject {
    var id: String { get }
    var type: ModuleType { get }
    var settingsPublisher: AnyPublisher<ModuleSettings, Never> { get }
    
    func updateSettings(_ settings: ModuleSettings)
    func handleContext(_ context: ModuleContext)
}

enum ModuleType {
    case transcription
    case translation
    case messaging
    case calls
    case videoCall
    case textEditor
}

struct ModuleSettings: Codable {
    let preferences: [String: Any]
    let configurations: [String: Any]
    
    // Implementera Codable manuellt för Any-typer
    private enum CodingKeys: String, CodingKey {
        case preferences, configurations
    }
}

struct ModuleContext {
    let sourceModule: String
    let targetModule: String
    let data: [String: Any]
    let timestamp: Date
}

struct ModuleConnection {
    let moduleA: Module
    let moduleB: Module
    
    func involves(_ module: Module) -> Bool {
        moduleA.id == module.id || moduleB.id == module.id
    }
    
    func modules(excluding module: Module) -> [Module] {
        [moduleA, moduleB].filter { $0.id != module.id }
    }
}

// MARK: - Context Bridge

final class ContextBridge {
    private var connections: [String: Set<Module>] = [:]
    
    func establishConnection(between moduleA: Module, and moduleB: Module) {
        let connectionKey = createConnectionKey(moduleA, moduleB)
        connections[connectionKey, default: []].insert(moduleA)
        connections[connectionKey, default: []].insert(moduleB)
    }
    
    func shareContext(from source: Module, to target: Module, context: ModuleContext) {
        let connectionKey = createConnectionKey(source, target)
        guard connections[connectionKey]?.contains(target) == true else { return }
        target.handleContext(context)
    }
    
    private func createConnectionKey(_ moduleA: Module, _ moduleB: Module) -> String {
        let ids = [moduleA.id, moduleB.id].sorted()
        return ids.joined(separator: "-")
    }
}
