import SwiftUI
import CoreHaptics

struct WaveNavigationIcon: View {
    @StateObject private var viewModel = WaveNavigationViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    private let baseRadius: CGFloat = 32
    private let waveHeight: CGFloat = 8
    
    var body: some View {
        ZStack {
            // Base circle with gradient
            Circle()
                .fill(
                    colorScheme == .dark ? 
                        PremiumDesignSystem.Colors.gradient(.dark) :
                        PremiumDesignSystem.Colors.gradient(.light)
                )
                .frame(width: baseRadius * 2, height: baseRadius * 2)
                .shadow(radius: viewModel.isActive ? 8 : 4)
            
            // Animated wave
            WaveShape(
                amplitude: viewModel.waveAmplitude,
                frequency: viewModel.waveFrequency,
                phase: viewModel.wavePhase
            )
            .fill(colorScheme == .dark ? Color.white : Color.black)
            .opacity(0.8)
            .frame(width: baseRadius * 2, height: waveHeight)
            .mask(
                RoundedRectangle(cornerRadius: waveHeight / 2)
                    .frame(width: baseRadius * 1.8, height: waveHeight)
            )
            
            // Audio level spikes
            AudioLevelSpikes(
                levels: viewModel.audioLevels,
                baseHeight: waveHeight,
                color: colorScheme == .dark ? .white : .black
            )
            .opacity(0.6)
        }
        .overlay(
            Circle()
                .stroke(
                    colorScheme == .dark ? Color.white : Color.black,
                    lineWidth: 1
                )
                .opacity(0.1)
        )
        .scaleEffect(viewModel.isPressed ? 0.95 : 1.0)
        .onTapGesture {
            viewModel.handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            viewModel.handleLongPress()
        }
    }
}

struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get {
            AnimatablePair(
                AnimatablePair(amplitude, frequency),
                phase
            )
        }
        set {
            amplitude = newValue.first.first
            frequency = newValue.first.second
            phase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let y = midHeight + sin(relativeX * .pi * frequency + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct AudioLevelSpikes: View {
    let levels: [CGFloat]
    let baseHeight: CGFloat
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: baseHeight * (1 + levels[index]))
                    .animation(.spring(response: 0.3), value: levels[index])
            }
        }
    }
}

@MainActor
class WaveNavigationViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPressed = false
    @Published private(set) var waveAmplitude: CGFloat = 0
    @Published private(set) var waveFrequency: CGFloat = 2
    @Published private(set) var wavePhase: CGFloat = 0
    @Published private(set) var audioLevels: [CGFloat] = Array(repeating: 0, count: 7)
    
    private var waveDisplayLink: DisplayLinkPublisher?
    private var audioLevelTimer: Timer?
    private let hapticEngine = PremiumDesignSystem.HapticEngine.shared
    
    private var phaseAnimation: CGFloat = 0
    private var warningVibrationTask: Task<Void, Never>?
    
    func handleTap() {
        isPressed = true
        hapticEngine.playFeedback(.mediumTap)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPressed = false
        }
    }
    
    func handleLongPress() {
        toggleActive()
    }
    
    func toggleActive() {
        isActive.toggle()
        
        if isActive {
            startWaveAnimation()
            hapticEngine.playFeedback(.recording)
        } else {
            stopWaveAnimation()
            hapticEngine.playFeedback(.stopRecording)
        }
    }
    
    func updateAudioLevel(_ level: Float) {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        
        if normalizedLevel < 0.1 {
            startWarningVibration()
        } else {
            stopWarningVibration()
        }
        
        // Update audio level spikes
        let newLevel = normalizedLevel * 2
        audioLevels.removeFirst()
        audioLevels.append(newLevel)
    }
    
    private func startWaveAnimation() {
        waveDisplayLink = DisplayLinkPublisher()
        waveDisplayLink?.sink { [weak self] _ in
            self?.updateWaveAnimation()
        }.store(in: &cancellables)
        
        withAnimation(.spring()) {
            waveAmplitude = 4
        }
    }
    
    private func stopWaveAnimation() {
        waveDisplayLink = nil
        
        withAnimation(.spring()) {
            waveAmplitude = 0
        }
    }
    
    private func updateWaveAnimation() {
        phaseAnimation += 0.05
        wavePhase = phaseAnimation
        
        if isActive {
            // Subtle amplitude variation
            let variation = sin(phaseAnimation * 0.5) * 0.5
            withAnimation(.linear(duration: 0.1)) {
                waveAmplitude = 4 + variation
            }
        }
    }
    
    private func startWarningVibration() {
        guard warningVibrationTask == nil else { return }
        
        warningVibrationTask = Task {
            while !Task.isCancelled {
                hapticEngine.playFeedback(.error)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }
    
    private func stopWarningVibration() {
        warningVibrationTask?.cancel()
        warningVibrationTask = nil
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// Helper for smooth animation
class DisplayLinkPublisher: ObservableObject {
    private var displayLink: CADisplayLink?
    private var subscribers = Set<AnyCancellable>()
    
    init() {
        let publisher = PassthroughSubject<Void, Never>()
        
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
        
        publisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)
    }
    
    @objc private func update() {
        objectWillChange.send()
    }
    
    deinit {
        displayLink?.invalidate()
    }
}
