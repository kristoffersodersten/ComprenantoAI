import SwiftUI

struct WaveNavigationHub: View {
    @StateObject private var viewModel = WaveNavigationViewModel()
    @StateObject private var navigationViewModel = PremiumNavigationViewModel()
    
    var body: some View {
        ZStack {
            // Fan navigation when expanded
            if navigationViewModel.isExpanded {
                ModuleFan(viewModel: navigationViewModel)
                    .transition(.opacity)
            }
            
            // Central wave icon
            WaveNavigationIcon()
                .onTapGesture {
                    navigationViewModel.toggleExpansion()
                }
        }
    }
}
