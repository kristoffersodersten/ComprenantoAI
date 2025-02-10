import AVFoundation
import Accelerate
import Combine
import Foundation
import os.log

enum AudioManagerError: Error {
    case audioLoadingFailed(Error)
    case audioSessionSetupFailed(Error)
    case waveformGenerationFailed(Error)
}

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "AudioManager")

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0 {
        didSet {
            audioPlayer?.volume = volume
        }
    }
    @Published var audioSamples: [Float] = []

    private override init() {
        super.init()
        do {
            try setupAudioSession()
        } catch {
            log.error("Failed to setup audio session: \(error)")
        }
    }

    func loadAudio(from url: URL, completion: @escaping (Result<Void, AudioManagerError>) -> Void) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            duration = audioPlayer?.duration ?? 0
            generateWaveform(from: audioPlayer?.data) { result in
                switch result {
                case .success:
                    self.log.info("Audio loaded successfully")
                    completion(.success(()))
                case .failure(let error):
                    self.log.error("Waveform generation failed: \(error)")
                    completion(.failure(.waveformGenerationFailed(error)))
                }
            }
        } catch {
            log.error("Failed to load audio: \(error)")
            completion(.failure(.audioLoadingFailed(error)))
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
        log.info("Started playback")
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        log.info("Paused playback")
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
        log.info("Stopped playback")
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        log.info("Seeked to time: \(time)")
    }

    func skipForward() {
        seek(to: currentTime + 15)
    }

    func skipBackward() {
        seek(to: max(currentTime - 15, 0))
    }

    private func setupAudioSession() throws {
        // AVAudioSession is not available on macOS, so this code is removed
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.currentTime = self?.audioPlayer?.currentTime ?? 0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func generateWaveform(from data: Data?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let data = data else {
            completion(.failure(NSError(domain: "NoAudioData", code: -1, userInfo: nil)))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioBuffer = try self.createAudioBuffer(from: data)
                let waveform = self.calculateWaveform(from: audioBuffer)
                DispatchQueue.main.async {
                    self.audioSamples = waveform
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func calculateWaveform(from buffer: AVAudioPCMBuffer) -> [Float] {
        let channelData = buffer.floatChannelData?[0]
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        return samples
    }

    private func createAudioBuffer(from data: Data) throws -> AVAudioPCMBuffer {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory() + "tempAudio.caf")
        guard let audioFile = try? AVAudioFile(forWriting: tempURL, settings: [:]) else {
            throw NSError(domain: "AudioFileCreation", code: -1, userInfo: nil)
        }
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!
        let frameCapacity = UInt32(data.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = buffer.frameCapacity
        _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            memcpy(buffer.floatChannelData![0], bytes.baseAddress!, data.count)
        }
        try audioFile.write(from: buffer)
        try audioFile.read(into: buffer)
        return buffer
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
        log.info("Playback finished")
    }
}
