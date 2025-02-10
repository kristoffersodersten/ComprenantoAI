import AVFoundation
import Accelerate

class EnhancedAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let noiseReductionNode = AVAudioUnitEQ(numberOfBands: 1)
    private let compressorNode = AVAudioUnitDynamicsProcessor()
    private let mixerNode = AVAudioMixerNode()
    
    private var audioLevelMonitor: Timer?
    private var audioLevelCallback: ((Float) -> Void)?
    
    init() {
        setupAudioSession()
        setupSignalChain()
        setupNoiseReduction()
        setupCompressor()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupSignalChain() {
        // Attach nodes
        audioEngine.attach(noiseReductionNode)
        audioEngine.attach(compressorNode)
        audioEngine.attach(mixerNode)
        
        // Connect nodes
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        audioEngine.connect(inputNode, to: noiseReductionNode, format: format)
        audioEngine.connect(noiseReductionNode, to: compressorNode, format: format)
        audioEngine.connect(compressorNode, to: mixerNode, format: format)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: format)
    }
    
    private func setupNoiseReduction() {
        // Configure noise reduction
        let band = noiseReductionNode.bands[0]
        band.filterType = .lowPass
        band.frequency = 7000 // Cut off high frequencies
        band.bandwidth = 0.5
        band.bypass = false
        
        noiseReductionNode.globalGain = -15
    }
    
    private func setupCompressor() {
        // Configure compressor for better dynamic range
        compressorNode.threshold = -15 // dB
        compressorNode.headRoom = 5 // dB
        compressorNode.expansionRatio = 2
        compressorNode.attackTime = 0.001 // seconds
        compressorNode.releaseTime = 0.1 // seconds
    }
    
    func startMonitoring(levelCallback: @escaping (Float) -> Void) {
        audioLevelCallback = levelCallback
        
        // Install tap on mixer node to monitor levels
        let format = mixerNode.outputFormat(forBus: 0)
        mixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, time in
            self?.processTapBlock(buffer: buffer, time: time)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopMonitoring() {
        mixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioLevelCallback = nil
    }
    
    private func processTapBlock(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = UInt(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square) power
        var rms: Float = 0
        vDSP_measqv(channelData, 1, &rms, frames)
        rms = sqrt(rms)
        
        // Convert to decibels
        var db = 20 * log10(rms)
        
        // Normalize
        db = max(-60, min(db, 0))
        let normalizedValue = (db + 60) / 60
        
        // Report level on main thread
        DispatchQueue.main.async { [weak self] in
            self?.audioLevelCallback?(normalizedValue)
        }
    }
    
    func setInputGain(_ gain: Float) {
        mixerNode.volume = gain
    }
}
