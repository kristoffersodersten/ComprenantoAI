import SwiftData
import Foundation

enum ComprenantoSchema {
    static let schema = Schema([
        Item.self,
        TranscriptionSession.self,
        TranslationSession.self,
        Message.self,
        CallSession.self,
        UserPreferences.self
    ])
    
    static let configurations = [
        ModelConfiguration(
            for: Item.self,
            isStoredInMemoryOnly: false
        ),
        ModelConfiguration(
            for: TranscriptionSession.self,
            isStoredInMemoryOnly: false
        ),
        ModelConfiguration(
            for: TranslationSession.self,
            isStoredInMemoryOnly: false
        ),
        ModelConfiguration(
            for: Message.self,
            isStoredInMemoryOnly: false
        ),
        ModelConfiguration(
            for: CallSession.self,
            isStoredInMemoryOnly: false
        ),
        ModelConfiguration(
            for: UserPreferences.self,
            isStoredInMemoryOnly: false
        )
    ]
}
