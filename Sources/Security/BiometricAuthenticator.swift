import LocalAuthentication
import Combine
import os.log

enum BiometricError: Error {
    case authenticationFailed(LAError)
    case notAvailable(String)
    case notEnrolled
    case cancelled
    case systemError(Error)
    case policyError(String)
}

actor BiometricAuthenticator {
    static let shared = BiometricAuthenticator()
    
    // Core properties
    private let context = LAContext()
    private let log = Logger(subsystem: "com.comprenanto", category: "BiometricAuth")
    
    // State management
    @Published private(set) var isAuthenticating = false
    private var lastAuthTime: Date?
    
    // Configuration
    private let authTimeout: TimeInterval = 300 // 5 minutes
    private let maxAttempts = 3
    private var attemptCount = 0
    
    // Publishers
    let authStatePublisher = PassthroughSubject<AuthenticationState, Never>()
    
    // MARK: - Types
    
    enum BiometricType {
        case faceID
        case touchID
        case none
        
        var description: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "None"
            }
        }
    }
    
    enum AuthenticationState {
        case authenticated
        case failed(BiometricError)
        case locked
        case requiresUpgrade
    }
    
    struct AuthenticationPolicy {
        let requiresBiometrics: Bool
        let fallbackEnabled: Bool
        let gracePeriod: TimeInterval
        
        static let standard = AuthenticationPolicy(
            requiresBiometrics: true,
            fallbackEnabled: true,
            gracePeriod: 300
        )
    }
    
    // MARK: - Public Methods
    
    func authenticate(
        reason: String = "Verify your identity",
        policy: AuthenticationPolicy = .standard
    ) async throws -> Bool {
        guard !isAuthenticating else {
            throw BiometricError.policyError("Authentication already in progress")
        }
        
        // Check if within grace period
        if let lastAuth = lastAuthTime,
           Date().timeIntervalSince(lastAuth) < policy.gracePeriod {
            return true
        }
        
        // Check attempt limit
        guard attemptCount < maxAttempts else {
            authStatePublisher.send(.locked)
            throw BiometricError.policyError("Too many attempts")
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            let supported = try await checkBiometricSupport()
            guard supported else {
                if policy.fallbackEnabled {
                    return try await authenticateWithPasscode(reason: reason)
                }
                throw BiometricError.notAvailable("Biometrics not available")
            }
            
            return try await evaluateBiometricPolicy(reason: reason)
        } catch {
            attemptCount += 1
            throw error
        }
    }
    
    func getBiometricType() async -> BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    func resetState() {
        attemptCount = 0
        lastAuthTime = nil
        context.invalidate()
    }
    
    // MARK: - Private Methods
    
    private func checkBiometricSupport() async throws -> Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error as? LAError {
            switch error.code {
            case .biometryNotEnrolled:
                throw BiometricError.notEnrolled
            case .biometryNotAvailable:
                throw BiometricError.notAvailable("Biometrics not available")
            default:
                throw BiometricError.systemError(error)
            }
        }
        
        return canEvaluate
    }
    
    private func evaluateBiometricPolicy(reason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    self.lastAuthTime = Date()
                    self.attemptCount = 0
                    self.authStatePublisher.send(.authenticated)
                    continuation.resume(returning: true)
                } else if let error = error as? LAError {
                    let biometricError = self.handleAuthenticationError(error)
                    continuation.resume(throwing: biometricError)
                } else {
                    continuation.resume(throwing: BiometricError.systemError(error ?? NSError()))
                }
            }
        }
    }
    
    private func authenticateWithPasscode(reason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                if success {
                    self.lastAuthTime = Date()
                    self.attemptCount = 0
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: BiometricError.authenticationFailed(
                        error as? LAError ?? LAError(.authenticationFailed)
                    ))
                }
            }
        }
    }
    
    private func handleAuthenticationError(_ error: LAError) -> BiometricError {
        log.error("Authentication error: \(error.localizedDescription)")
        
        switch error.code {
        case .userCancel, .systemCancel, .appCancel:
            return .cancelled
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryNotAvailable:
            return .notAvailable("Biometrics not available")
        default:
            return .authenticationFailed(error)
        }
    }
}

// MARK: - Convenience Extensions

extension BiometricAuthenticator {
    func authenticateWithFallback(
        reason: String = "Verify your identity",
        fallbackReason: String = "Please enter your passcode"
    ) async throws -> Bool {
        do {
            return try await authenticate(reason: reason)
        } catch BiometricError.notAvailable where context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            return try await authenticateWithPasscode(reason: fallbackReason)
        } catch {
            throw error
        }
    }
}

// MARK: - Usage Example

extension BiometricAuthenticator {
    static func example() async {
        let authenticator = BiometricAuthenticator.shared
        
        do {
            // Check biometric type
            let biometricType = await authenticator.getBiometricType()
            print("Available biometric: \(biometricType.description)")
            
            // Authenticate with custom policy
            let policy = AuthenticationPolicy(
                requiresBiometrics: true,
                fallbackEnabled: true,
                gracePeriod: 600
            )
            
            let authenticated = try await authenticator.authenticate(
                reason: "Verify to start interpretation",
                policy: policy
            )
            
            if authenticated {
                print("Authentication successful")
            }
        } catch {
            print("Authentication failed: \(error)")
        }
    }
}
