import Foundation

struct LicenseManager {
    static let licenseText: String = {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let licenseData = try? Data(contentsOf: url),
              let licenseText = String(data: licenseData, encoding: .utf8) else {
            return "License information not available."
        }
        return licenseText
    }()
    
    static func showLicenseInformation() {
        print(licenseText)
        // In a real app, you might want to display this in a UI component
    }
}
