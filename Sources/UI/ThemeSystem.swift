import SwiftUI

struct ThemeSystem {
    static let colors = Colors()
    static let spacing = Spacing()
    static let radius = CornerRadius()
    
    struct Colors {
        let primary = Color("PrimaryColor")
        let secondary = Color("SecondaryColor")
        let background = Color("BackgroundColor")
        let text = Color("TextColor")
        let accent = Color("AccentColor")
        
        func adaptiveColor(light: Color, dark: Color) -> Color {
            Color(UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(dark)
                default:
                    return UIColor(light)
                }
            })
        }
    }
    
    struct Spacing {
        let small: CGFloat = 8
        let medium: CGFloat = 16
        let large: CGFloat = 24
        let extraLarge: CGFloat = 32
    }
    
    struct CornerRadius {
        let small: CGFloat = 8
        let medium: CGFloat = 12
        let large: CGFloat = 16
        let extraLarge: CGFloat = 24
    }
}

struct ThemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(colorScheme)
            .environment(\.colorScheme, colorScheme)
    }
}
