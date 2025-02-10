import SwiftUI
import os.log

enum ThemeManagerError: Error {
    case themeSettingError(String, Error?)
}

class ThemeManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "ThemeManager")
    @Published var currentTheme: Theme = .system {
        didSet {
            saveTheme()
        }
    }

    enum Theme: String, Codable, CaseIterable {
        case light, dark, system
    }

    struct Colors {
        static let lightBackground = Color(hex: "F5F2EE")
        static let lightSurface = Color(hex: "FFFFFF")
        static let lightText = Color(hex: "1A1A1A")

        static let darkBackground = Color(hex: "1C1C1E")
        static let darkSurface = Color(hex: "2C2C2E")
        static let darkText = Color(hex: "FFFFFF")

        static func silverGradient(for colorScheme: ColorScheme) -> LinearGradient {
            LinearGradient(
                colors: colorScheme == .dark ?
                    [Color(hex: "4A4A4A")!, Color(hex: "7D7D7D")!] :
                    [Color(hex: "D1D1D6")!, Color(hex: "F2F2F7")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func goldGradient(for colorScheme: ColorScheme) -> LinearGradient {
            LinearGradient(
                colors: colorScheme == .dark ?
                    [Color(hex: "B7995C")!, Color(hex: "DAB96B")!] :
                    [Color(hex: "FFD700")!, Color(hex: "FFF0A3")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static let accessibilityPrimary = Color(hex: "0080FF")!
        static let accessibilitySecondary = Color(hex: "5856D6")!
    }

    struct Typography {
        static func sfProText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func sfProDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    struct Dimensions {
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 8
        static let buttonHeight: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let spacing: CGFloat = 16
    }

    struct Animations {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
        static let shimmer = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }

    init() {
        if let themeString = userDefaults.string(forKey: "currentTheme"), let theme = Theme(rawValue: themeString) {
            currentTheme = theme
        }
    }

    func toggleTheme() {
        switch currentTheme {
        case .light: currentTheme = .dark
        case .dark: currentTheme = .light
        case .system: currentTheme = .light
        }
    }

    static func applyGlossyEffect(to view: AnyView) -> some View {
        view.overlay(
            LinearGradient(
                gradient: Gradient(colors: [.white.opacity(0.3), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
    }

    private func saveTheme() {
        do {
            let encoded = try JSONEncoder().encode(currentTheme)
            userDefaults.set(encoded, forKey: "currentTheme")
            log.info("Theme saved: \(String(describing: self.currentTheme))")
        } catch {
            log.error("Error saving theme: \(String(describing: error))")
        }
    }
}

extension Color {
    init?(hex: String) {
        let red, green, blue, alpha: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    red = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    green = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    blue = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    alpha = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: red, green: green, blue: blue, opacity: alpha)
                    return
                }
            } else if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    red = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    green = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    blue = CGFloat(hexNumber & 0x0000ff) / 255
                    alpha = 1.0

                    self.init(red: red, green: green, blue: blue, opacity: alpha)
                    return
                }
            }
        }

        return nil
    }
}
