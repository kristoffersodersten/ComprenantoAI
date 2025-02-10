import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Reduce Motion", isOn: $settingsManager.reduceMotion)
                    Toggle("Increase Contrast", isOn: $settingsManager.increaseContrast)
                }
                
                Section(header: Text("Language")) {
                    Picker("Primary Language", selection: $settingsManager.primaryLanguage) {
                        ForEach(settingsManager.availableLanguages, id: \.code) { language in
                            Text(language.name).tag(language)
                        }
                    }
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Enable Analytics", isOn: $settingsManager.enableAnalytics)
                    Toggle("Share Usage Data", isOn: $settingsManager.shareUsageData)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $settingsManager.enableNotifications)
                }
                
                Section {
                    Button("Reset All Settings") {
                        settingsManager.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
