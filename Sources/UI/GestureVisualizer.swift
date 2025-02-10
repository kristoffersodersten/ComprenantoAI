import SwiftUI
import CoreGraphics

struct GestureVisualizer: View {
    let gesture: Gesture
    let intent: GestureIntent
    
    @State private var showingTrajectory = true
    @State private var showingConfidence = true
    
    var body: some View {
        ZStack {
            // Trajectory visualization
            if showingTrajectory {
                TrajectoryView(trajectory: gesture.trajectory)
                    .stroke(Color.blue, lineWidth: 2)
                    .opacity(0.6)
            }
            
            // Hand pose visualization
            HandPoseView(pose: gesture.pose)
                .stroke(Color.green, lineWidth: 2)
            
            // Confidence indicator
            if showingConfidence {
                ConfidenceIndicator(confidence: gesture.confidence)
                    .frame(width: 60, height: 60)
                    .position(x: 40, y: 40)
            }
            
            // Intent visualization
            IntentVisualizer(intent: intent)
        }
    }
}

struct TrajectoryView: Shape {
    let trajectory: Trajectory
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard let first = trajectory.points.first else { return path }
        
        path.move(to: first)
        for point in trajectory.points.dropFirst() {
            path.addLine(to: point)
        }
        
        return path
    }
}

struct HandPoseView: Shape {
    let pose: HandPose
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Draw hand landmarks
        for landmark in pose.landmarks {
            path.addEllipse(in: CGRect(
                x: landmark.x - 4,
                y: landmark.y - 4,
                width: 8,
                height: 8
            ))
        }
        
        // Draw connections
        for connection in pose.connections {
            let from = pose.landmarks[connection.from]
            let to = pose.landmarks[connection.to]
            path.move(to: from)
            path.addLine(to: to)
        }
        
        return path
    }
}

struct ConfidenceIndicator: View {
    let confidence: Float
    
    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(confidence))
            .stroke(
                Color.blue,
                style: StrokeStyle(
                    lineWidth: 4,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90))
            .animation(.spring(), value: confidence)
    }
}

struct IntentVisualizer: View {
    let intent: GestureIntent
    
    var body: some View {
        switch intent.primary {
        case .navigation(let nav):
            NavigationIntentView(intent: nav)
        case .manipulation(let manip):
            ManipulationIntentView(intent: manip)
        case .system(let sys):
            SystemIntentView(intent: sys)
        }
    }
}

struct NavigationIntentView: View {
    let intent: GestureIntent.NavigationIntent
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.blue)
    }
    
    private var iconName: String {
        switch intent {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .home: return "house.fill"
        }
    }
}

struct ManipulationIntentView: View {
    let intent: GestureIntent.ManipulationIntent
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.green)
    }
    
    private var iconName: String {
        switch intent {
        case .select: return "checkmark.circle.fill"
        case .zoom: return "magnifyingglass"
        case .rotate: return "arrow.clockwise"
        case .drag: return "hand.draw.fill"
        }
    }
}

struct SystemIntentView: View {
    let intent: GestureIntent.SystemIntent
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.orange)
    }
    
    private var iconName: String {
        switch intent {
        case .cancel: return "xmark.circle.fill"
        case .confirm: return "checkmark.circle.fill"
        case .menu: return "line.horizontal.3"
        case .settings: return "gear"
        }
    }
}
