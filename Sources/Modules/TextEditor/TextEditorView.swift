import SwiftUI

struct TextEditorView: View {
    @StateObject private var viewModel = TextEditorViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(viewModel: viewModel)
            
            ScrollView {
                TextEditor(text: $viewModel.text)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .padding()
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(PremiumDesignSystem.Layout.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: PremiumDesignSystem.Layout.cornerRadius)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()
            
            if viewModel.isShowingSuggestions {
                SuggestionView(viewModel: viewModel)
            }
            
            EditorControlBar(viewModel: viewModel)
        }
        .navigationTitle("Text Editor")
        .background(colorScheme == .dark ? Color.black : Color(hex: "F5F2EE"))
        .alert(item: $viewModel.activeAlert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

struct EditorToolbar: View {
    @ObservedObject var viewModel: TextEditorViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(TextEditorViewModel.ToolbarItem.allCases, id: \.self) { item in
                    Button(action: { viewModel.handleToolbarAction(item) }) {
                        Image(systemName: item.iconName)
                            .foregroundColor(.primary)
                    }
                    .premiumButtonStyle(feedback: .lightTap)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}

struct SuggestionView: View {
    @ObservedObject var viewModel: TextEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.headline)
            
            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button(action: { viewModel.applySuggestion(suggestion) }) {
                    Text(suggestion)
                        .foregroundColor(.primary)
                }
                .premiumButtonStyle(feedback: .mediumTap)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(PremiumDesignSystem.Layout.cornerRadius)
        .shadow(radius: 2)
        .padding()
    }
}

struct EditorControlBar: View {
    @ObservedObject var viewModel: TextEditorViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: viewModel.translateText) {
                Image(systemName: "globe")
            }
            .premiumButtonStyle(feedback: .mediumTap)
            
            Button(action: viewModel.checkGrammar) {
                Image(systemName: "checkmark.circle")
            }
            .premiumButtonStyle(feedback: .mediumTap)
            
            Button(action: viewModel.improveStyle) {
                Image(systemName: "wand.and.stars")
            }
            .premiumButtonStyle(feedback: .mediumTap)
            
            Spacer()
            
            Button(action: viewModel.shareText) {
                Image(systemName: "square.and.arrow.up")
            }
            .premiumButtonStyle(feedback: .mediumTap)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
