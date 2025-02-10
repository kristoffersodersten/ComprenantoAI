import SwiftUI

extension View {
    /// Pins the view to all edges of its parent
    func pinToEdges() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Pins the view to all edges of its parent with specified padding
    func pinToEdges(padding: CGFloat) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
    }
    
    /// Pins the view to all edges of its parent with custom edge insets
    func pinToEdges(edges: Edge.Set, padding: CGFloat = 0) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(edges, padding)
    }
}

struct EdgePinModifier: ViewModifier {
    let alignment: Alignment
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

extension View {
    /// Pins the view to edges with specified alignment
    func pinToEdges(alignment: Alignment) -> some View {
        modifier(EdgePinModifier(alignment: alignment))
    }
}

struct SafeAreaPinModifier: ViewModifier {
    let edges: Edge.Set
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(edges)
    }
}

extension View {
    /// Pins the view to edges ignoring safe area
    func pinToEdgesIgnoringSafeArea(_ edges: Edge.Set = .all) -> some View {
        modifier(SafeAreaPinModifier(edges: edges))
    }
}

// Usage example:
struct LayoutExampleView: View {
    var body: some View {
        VStack {
            // Pin to all edges
            Color.blue.opacity(0.3)
                .pinToEdges()
            
            // Pin with padding
            Color.red.opacity(0.3)
                .pinToEdges(padding: 20)
            
            // Pin specific edges
            Color.green.opacity(0.3)
                .pinToEdges(edges: [.horizontal], padding: 16)
            
            // Pin with alignment
            Text("Aligned Content")
                .pinToEdges(alignment: .topLeading)
            
            // Pin ignoring safe area
            Color.purple.opacity(0.3)
                .pinToEdgesIgnoringSafeArea()
        }
    }
}

#Preview {
    LayoutExampleView()
}
