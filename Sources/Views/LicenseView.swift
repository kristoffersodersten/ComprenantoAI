import SwiftUI

struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text(LicenseManager.licenseText)
                .padding()
                .font(.footnote)
        }
        .navigationTitle("License")
    }
}

#Preview {
    NavigationView {
        LicenseView()
    }
}
