import SwiftUI

struct DynamicTypeSystem {
    static let scaledFont = ScaledFont()
    
    struct ScaledFont {
        let largeTitle = Font.largeTitle.weight(.bold)
        let title = Font.title.weight(.semibold)
        let headline = Font.headline
        let body = Font.body
        let callout = Font.callout
        let caption = Font.caption
        
        func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

struct ScaledFontModifier: ViewModifier {
    let style: Font
    let maxSize: CGFloat?
    
    func body(content: Content) -> some View {
        content
            .font(style)
            .lineLimit(nil)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func scaledFont(_ style: Font, maxSize: CGFloat? = nil) -> some View {
        modifier(ScaledFontModifier(style: style, maxSize: maxSize))
    }
}
