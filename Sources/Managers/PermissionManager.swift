import SwiftUI
import AVFoundation
import Photos
import Speech
import CoreLocation

enum PermissionType {
    case microphone
    case camera
    case photoLibrary
    case speechRecognition
    case location
    
    var description: String {
        switch self {
        case .microphone:
            return "Microphone access is needed for voice calls and speech recognition"
        case .camera:
            return "Camera access is needed for video calls"
        case .photoLibrary:
            return "Photo library access is needed to share images"
        case .speechRecognition:
            return "Speech recognition is needed for transcription"
        case .location:
            return "Location is used for regional language suggestions"
        }
    }
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published private(set) var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    
    private let locationManager = CLLocationManager()
    
    func requestPermission(_ type: PermissionType) async -> PermissionStatus {
        switch type {
        case .microphone:
            return await requestMicrophonePermission()
        case .camera:
            return await requestCameraPermission()
        case .photoLibrary:
            return await requestPhotoLibraryPermission()
        case .speechRecognition:
            return await requestSpeechRecognitionPermission()
        case .location:
            return await requestLocationPermission()
        }
    }
    
    private func requestMicrophonePermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                let status: PermissionStatus = granted ? .authorized : .denied
                DispatchQueue.main.async {
                    self.permissionStatuses[.microphone] = status
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestCameraPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                let status: PermissionStatus = granted ? .authorized : .denied
                DispatchQueue.main.async {
                    self.permissionStatuses[.camera] = status
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestPhotoLibraryPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                let permissionStatus: PermissionStatus
                switch status {
                case .authorized, .limited: permissionStatus = .authorized
                case .denied: permissionStatus = .denied
                case .restricted: permissionStatus = .restricted
                case .notDetermined: permissionStatus = .notDetermined
                @unknown default: permissionStatus = .denied
                }
                DispatchQueue.main.async {
                    self.permissionStatuses[.photoLibrary] = permissionStatus
                }
                continuation.resume(returning: permissionStatus)
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let permissionStatus: PermissionStatus
                switch status {
                case .authorized: permissionStatus = .authorized
                case .denied: permissionStatus = .denied
                case .restricted: permissionStatus = .restricted
                case .notDetermined: permissionStatus = .notDetermined
                @unknown default: permissionStatus = .denied
                }
                DispatchQueue.main.async {
                    self.permissionStatuses[.speechRecognition] = permissionStatus
                }
                continuation.resume(returning: permissionStatus)
            }
        }
    }
    
    private func requestLocationPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            locationManager.requestWhenInUseAuthorization()
            let status: PermissionStatus
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                status = .authorized
            case .denied:
                status = .denied
            case .restricted:
                status = .restricted
            case .notDetermined:
                status = .notDetermined
            @unknown default:
                status = .denied
            }
            DispatchQueue.main.async {
                self.permissionStatuses[.location] = status
            }
            continuation.resume(returning: status)
        }
    }
}

struct PermissionRequestView: View {
    let type: PermissionType
    let action: () async -> Void
    
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text(type.description)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                Task {
                    await requestPermission()
                }
            }) {
                Text("Grant Access")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .alert("Permission Required", isPresented: $showingSettings) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable access in Settings to use this feature.")
        }
    }
    
    private var iconName: String {
        switch type {
        case .microphone: return "mic.fill"
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.fill"
        case .speechRecognition: return "waveform"
        case .location: return "location.fill"
        }
    }
    
    private func requestPermission() async {
        let status = await permissionManager.requestPermission(type)
        if status == .authorized {
            await action()
        } else {
            showingSettings = true
        }
    }
}

#Preview {
    PermissionRequestView(type: .microphone) {
        print("Permission granted")
    }
}
