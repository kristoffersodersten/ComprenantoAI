import SwiftUI

enum DesignSystem {
    enum Colors {
        static let primary = Color("PrimaryColor")
        static let secondary = Color("SecondaryColor")
        static let background = Color("BackgroundColor")
        static let surface = Color("SurfaceColor")
        
        static let cream = Color(hex: "F5F2EE")
        static let darkGray = Color(hex: "1C1C1E")
        
        enum Gradient {
            static let primary = LinearGradient(
                colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            static let surface = LinearGradient(
                colors: [Color.white.opacity(0.8), Color.white.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    enum Typography {
        static func sfProText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        
        static func sfProDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        
        static let title = sfProDisplay(34, weight: .bold)
        static let headline = sfProDisplay(28, weight: .semibold)
        static let subheadline = sfProText(17, weight: .semibold)
        static let body = sfProText(17)
        static let caption = sfProText(15)
    }
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
    
    enum Animation {
        static let spring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.7,
            blendDuration: 0
        )
        
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.3)
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
