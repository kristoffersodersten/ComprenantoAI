import SwiftUI
import CoreHaptics

enum DesignSystem {
    enum Animations {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let easeOut = Animation.easeOut(duration: 0.3)
        static let popIn = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }
    
    enum Haptics {
        static let engine = try? CHHapticEngine()
        
        static func playFeedback(_ type: FeedbackType) {
            switch type {
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            case .impact(let style):
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            case .notification(let type):
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(type)
            }
        }
        
        enum FeedbackType {
            case selection
            case impact(UIImpactFeedbackGenerator.FeedbackStyle)
            case notification(UINotificationFeedbackGenerator.FeedbackType)
        }
    }
    
    enum Layout {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let buttonHeight: CGFloat = 44
        
        enum Navigation {
            static let hubSize: CGFloat = 64
            static let fanRadius: CGFloat = 140
            static let fanSpacing: CGFloat = 60
            static let moduleIconSize: CGFloat = 48
        }
    }
    
    enum Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let accent = Color.orange
        
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        
        enum Gradient {
            static let primary = LinearGradient(
                colors: [.blue, .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            static let accent = LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    enum Shadows {
        static let small = Shadow(radius: 4, y: 2)
        static let medium = Shadow(radius: 8, y: 4)
        static let large = Shadow(radius: 16, y: 8)
        
        struct Shadow {
            let color: Color = .black.opacity(0.1)
            let radius: CGFloat
            let x: CGFloat = 0
            let y: CGFloat
        }
    }
}
