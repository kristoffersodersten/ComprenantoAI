import SwiftUI
import Combine

class TextEditorViewModel: ObservableObject {
    @Published var text = ""
    @Published var isShowingSuggestions = false
    @Published var suggestions: [String] = []
    @Published var activeAlert: AlertItem?
    
    private var cancellables = Set<AnyCancellable>()
    private let translationService: TranslationService
    private let grammarService: GrammarService
    private let styleService: StyleService
    
    enum ToolbarItem: CaseIterable {
        case bold, italic, underline, strikethrough, alignLeft, alignCenter, alignRight
        
        var iconName: String {
            switch self {
            case .bold: return "bold"
            case .italic: return "italic"
            case .underline: return "underline"
            case .strikethrough: return "strikethrough"
            case .alignLeft: return "text.alignleft"
            case .alignCenter: return "text.aligncenter"
            case .alignRight: return "text.alignright"
            }
        }
    }
    
    init(translationService: TranslationService = TranslationService(),
         grammarService: GrammarService = GrammarService(),
         styleService: StyleService = StyleService()) {
        self.translationService = translationService
        self.grammarService = grammarService
        self.styleService = styleService
        
        setupTextChangeListener()
    }
    
    func handleToolbarAction(_ item: ToolbarItem) {
        // Implementera formatering baserat på vald toolbar-åtgärd
        print("Toolbar action: \(item)")
    }
    
    func translateText() {
        Task {
            do {
                let translation = try await translationService.translate(text, to: "targetLanguage")
                await MainActor.run {
                    self.suggestions = [translation]
                    self.isShowingSuggestions = true
                }
            } catch {
                await MainActor.run {
                    self.activeAlert = AlertItem(title: "Translation Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func checkGrammar() {
        Task {
            do {
                let corrections = try await grammarService.checkGrammar(text)
                await MainActor.run {
                    self.suggestions = corrections
                    self.isShowingSuggestions = true
                }
            } catch {
                await MainActor.run {
                    self.activeAlert = AlertItem(title: "Grammar Check Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func improveStyle() {
        Task {
            do {
                let improvements = try await styleService.improveStyle(text)
                await MainActor.run {
                    self.suggestions = improvements
                    self.isShowingSuggestions = true
                }
            } catch {
                await MainActor.run {
                    self.activeAlert = AlertItem(title: "Style Improvement Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func shareText() {
        // Implementera delningsfunktionalitet
        print("Sharing text: \(text)")
    }
    
    func applySuggestion(_ suggestion: String) {
        text = suggestion
        isShowingSuggestions = false
    }
    
    private func setupTextChangeListener() {
        $text
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkGrammar()
            }
            .store(in: &cancellables)
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

class TranslationService {
    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        // Simulera översättning
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Translated: \(text)"
    }
}

class GrammarService {
    func checkGrammar(_ text: String) async throws -> [String] {
        // Simulera grammatikkontroll
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return ["Corrected: \(text)"]
    }
}

class StyleService {
    func improveStyle(_ text: String) async throws -> [String] {
        // Simulera stilförbättring
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return ["Improved: \(text)"]
    }
}
