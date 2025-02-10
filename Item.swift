import Foundation
import SwiftUI
import SwiftData

@Model
final class Item: Identifiable, Hashable {
    // MARK: - Properties
    
    /// Unique identifier for the item
    var id: UUID
    
    /// Name of the item
    var name: String
    
    /// Type of the item
    var type: ItemType
    
    /// Creation timestamp
    var createdAt: Date
    
    /// Last modification timestamp
    var modifiedAt: Date
    
    /// Optional detailed description
    var itemDescription: String?
    
    /// Associated language code (if applicable)
    var languageCode: String?
    
    /// Item metadata
    var metadata: [String: String]
    
    /// Favorite status
    var isFavorite: Bool
    
    // MARK: - Types
    
    enum ItemType: String, Codable, CaseIterable {
        case transcription
        case translation
        case message
        case call
        case note
        
        var icon: String {
            switch self {
            case .transcription: return "waveform"
            case .translation: return "globe"
            case .message: return "message.fill"
            case .call: return "phone.fill"
            case .note: return "note.text"
            }
        }
        
        var displayName: String {
            switch self {
            case .transcription: return "Transcription"
            case .translation: return "Translation"
            case .message: return "Message"
            case .call: return "Call"
            case .note: return "Note"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        type: ItemType,
        description: String? = nil,
        languageCode: String? = nil,
        metadata: [String: String] = [:],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.itemDescription = description
        self.languageCode = languageCode
        self.metadata = metadata
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // MARK: - Hashable
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Custom String Convertible

extension Item: CustomStringConvertible {
    var description: String {
        """
        Item(
            id: \(id),
            name: \(name),
            type: \(type.displayName),
            created: \(createdAt),
            modified: \(modifiedAt)
        )
        """
    }
}

// MARK: - Convenience Methods

extension Item {
    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }
    
    /// Adds or updates metadata
    func updateMetadata(_ key: String, value: String) {
        metadata[key] = value
        touch()
    }
    
    /// Creates a copy of the item
    func duplicate() -> Item {
        Item(
            name: "\(name) Copy",
            type: type,
            description: itemDescription,
            languageCode: languageCode,
            metadata: metadata,
            isFavorite: isFavorite
        )
    }
}

// MARK: - SwiftUI Preview Support

extension Item {
    static var preview: Item {
        Item(
            name: "Sample Item",
            type: .translation,
            description: "This is a sample item for preview",
            languageCode: "en",
            metadata: ["source": "preview"],
            isFavorite: true
        )
    }
}

// MARK: - SwiftUI Views

struct ItemRow: View {
    let item: Item
    
    var body: some View {
        HStack {
            Image(systemName: item.type.icon)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                
                if let description = item.itemDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ItemDetail: View {
    let item: Item
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Type", value: item.type.displayName)
                if let description = item.itemDescription {
                    LabeledContent("Description", value: description)
                }
                if let language = item.languageCode {
                    LabeledContent("Language", value: language)
                }
            }
            
            Section("Timestamps") {
                LabeledContent("Created", value: item.createdAt.formatted())
                LabeledContent("Modified", value: item.modifiedAt.formatted())
            }
            
            if !item.metadata.isEmpty {
                Section("Metadata") {
                    ForEach(item.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }
        }
        .navigationTitle(item.name)
    }
}

#Preview {
    NavigationView {
        ItemDetail(item: .preview)
    }
}
