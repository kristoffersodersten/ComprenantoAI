import SwiftUI
import ARKit

struct AROverlayView: View {
    @StateObject private var arController = ARViewController()
    
    var body: some View {
        ZStack {
            // AR-vy
            ARViewContainer(controller: arController)
            
            // Överlagringar
            if let detectedText = arController.detectedText {
                TranslationOverlay(text: detectedText)
            }
            
            // Kontroller
            ARControls(controller: arController)
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let controller: ARViewController
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        controller.setupAR(view: arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Uppdatera vid behov
    }
}

struct TranslationOverlay: View {
    let text: TranslatedText
    
    var body: some View {
        VStack {
            Text(text.original)
                .font(.system(size: 18, weight: .medium))
            
            Text(text.translated)
                .font(.system(size: 18, weight: .medium))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

final class ARViewController: ObservableObject {
    @Published private(set) var detectedText: TranslatedText?
    private let arEngine = HighPerformanceAREngine.shared
    
    func setupAR(view: ARSCNView) {
        // Konfigurera AR-session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .personSegmentation
        
        Task {
            try await arEngine.startAR(configuration: configuration)
        }
    }
}
