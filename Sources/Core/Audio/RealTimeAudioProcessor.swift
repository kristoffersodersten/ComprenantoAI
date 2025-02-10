import AVFoundation
import Accelerate
import Metal

final class RealTimeAudioProcessor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let audioEngine = AdvancedAudioEngine.shared
    private let captureSession = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "com.comprenanto.audio.output")
    
    // Realtidsbearbetning
    private let processingQueue: DispatchQueue
    private let audioBuffer: RingBuffer<Float>
    private var isProcessing = false
    
    override init() {
        self.processingQueue = DispatchQueue(
            label: "com.comprenanto.audio.processing",
            qos: .userInteractive,
            attributes: .concurrent
        )
        
        self.audioBuffer = RingBuffer(capacity: 44100 * 2) // 2 sekunder buffer
        
        super.init()
        
        setupAudioCapture()
    }
    
    // MARK: - Audio Processing
    
    func startProcessing() throws {
        guard !isProcessing else { return }
        
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothA2DP, .defaultToSpeaker]
        )
        
        captureSession.startRunning()
        isProcessing = true
        
        // Starta realtidsbearbetning
        processAudioInRealTime()
    }
    
    func stopProcessing() {
        guard isProcessing else { return }
        
        captureSession.stopRunning()
        isProcessing = false
    }
    
    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processingQueue.async { [weak self] in
            self?.processAudioBuffer(sampleBuffer)
        }
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let audioBuffer = extractAudioBuffer(from: sampleBuffer) else {
            return
        }
        
        Task {
            do {
                let processed = try await audioEngine.processAudioInRealTime(audioBuffer)
                await outputProcessedAudio(processed)
            } catch {
                print("Audio processing failed: \(error)")
            }
        }
    }
    
    private func outputProcessedAudio(_ audio: ProcessedAudio) async {
        // Outputta bearbetat ljud
        let buffer = audio.buffer
        
        // Konfigurera output format
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: buffer.sampleRate,
            channels: 1,
            interleaved: false
        )
        
        // Skapa audio buffer
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format!,
            frameCapacity: AVAudioFrameCount(buffer.length)
        )
        
        // Kopiera samples
        memcpy(
            pcmBuffer?.floatChannelData?[0],
            buffer.samples,
            buffer.length * MemoryLayout<Float>.stride
        )
        
        // Spela upp
        try? await playProcessedAudio(pcmBuffer!)
    }
}

// MARK: - Audio Utilities

extension RealTimeAudioProcessor {
    private func extractAudioBuffer(from sampleBuffer: CMSampleBuffer) -> AudioBuffer? {
        guard let audioBuffer = sampleBuffer.audioBuffer else {
            return nil
        }
        
        let frames = audioBuffer.frameLength
        var samples = [Float](repeating: 0, count: Int(frames))
        
        guard let channelData = audioBuffer.floatChannelData else {
            return nil
        }
        
        // Kopiera samples
        memcpy(
            &samples,
            channelData[0],
            Int(frames) * MemoryLayout<Float>.stride
        )
        
        return AudioBuffer(
            samples: samples,
            length: Int(frames),
            sampleRate: audioBuffer.format.sampleRate
        )
    }
    
    private func playProcessedAudio(_ buffer: AVAudioPCMBuffer) async throws {
        let player = AVAudioPlayerNode()
        let engine = AVAudioEngine()
        
        engine.attach(player)
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: buffer.format
        )
        
        try engine.start()
        
        player.scheduleBuffer(
            buffer,
            at: nil,
            options: .interrupts
        )
        player.play()
    }
}
