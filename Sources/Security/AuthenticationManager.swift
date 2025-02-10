import Foundation
import CryptoKit
import Combine
import os.log

enum AuthError: Error {
    case invalidCredentials
    case networkError(Error)
    case serverError(Int, String?)
    case tokenExpired
    case biometricsFailed(Error)
    case encryptionError(Error)
    case invalidSession
}

actor AuthenticationManager {
    static let shared = AuthenticationManager()
    
    // Core properties
    private let keychain: KeychainManager
    private let backendManager: BackendManagerProtocol
    private let log = Logger(subsystem: "com.comprenanto", category: "Authentication")
    
    // Authentication state
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    private var authToken: AuthToken?
    
    // Publishers
    let authStatePublisher = PassthroughSubject<AuthState, Never>()
    private var refreshTimer: Timer?
    
    // MARK: - Types
    
    struct AuthToken: Codable {
        let token: String
        let refreshToken: String
        let expiresAt: Date
        
        var isExpired: Bool {
            Date() >= expiresAt
        }
    }
    
    struct User: Codable {
        let id: String
        let username: String
        let email: String
        let preferredLanguages: [String]
        let settings: UserSettings
    }
    
    struct UserSettings: Codable {
        let autoTranslate: Bool
        let primaryLanguage: String
        let secondaryLanguages: [String]
        let usesBiometrics: Bool
        let notificationsEnabled: Bool
    }
    
    enum AuthState {
        case authenticated(User)
        case needsReauthentication
        case loggedOut
        case error(AuthError)
    }
    
    // MARK: - Initialization
    
    private init(
        baseURL: String = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.comprenanto.com"
    ) {
        self.keychain = KeychainManager.shared
        self.backendManager = BackendManager(baseURL: baseURL)
        
        setupTokenRefresh()
        restoreSession()
    }
    
    // MARK: - Public Methods
    
    func authenticate(
        username: String,
        password: String,
        biometricsEnabled: Bool = false
    ) async throws -> User {
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        // Hash password before sending
        let hashedPassword = hashPassword(password)
        
        let credentials = AuthCredentials(
            username: username,
            password: hashedPassword,
            deviceInfo: DeviceInfo.current
        )
        
        do {
            let response = try await backendManager.sendRequest(
                endpoint: "auth/login",
                method: "POST",
                body: credentials
            )
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.data)
            
            // Store authentication data
            authToken = authResponse.token
            currentUser = authResponse.user
            
            if biometricsEnabled {
                try await enableBiometrics(for: username)
            }
            
            // Store credentials securely
            try await storeCredentials(credentials)
            
            isAuthenticated = true
            authStatePublisher.send(.authenticated(authResponse.user))
            
            return authResponse.user
            
        } catch let error as HTTPError {
            log.error("Authentication failed: \(error.localizedDescription)")
            throw AuthError.serverError(error.statusCode, error.message)
        } catch {
            log.error("Authentication error: \(error.localizedDescription)")
            throw AuthError.networkError(error)
        }
    }
    
    func logout() async {
        do {
            if let token = authToken?.token {
                try await backendManager.sendRequest(
                    endpoint: "auth/logout",
                    method: "POST",
                    headers: ["Authorization": "Bearer \(token)"]
                )
            }
        } catch {
            log.error("Logout request failed: \(error.localizedDescription)")
        }
        
        // Clean up local state
        await cleanupSession()
    }
    
    func refreshToken() async throws {
        guard let refreshToken = authToken?.refreshToken else {
            throw AuthError.invalidSession
        }
        
        do {
            let response = try await backendManager.sendRequest(
                endpoint: "auth/refresh",
                method: "POST",
                body: ["refreshToken": refreshToken]
            )
            
            let newToken = try JSONDecoder().decode(AuthToken.self, from: response.data)
            authToken = newToken
            
            // Update keychain
            try await keychain.save(newToken, for: "authToken")
            
        } catch {
            log.error("Token refresh failed: \(error.localizedDescription)")
            await cleanupSession()
            throw AuthError.tokenExpired
        }
    }
    
    func validateSession() async throws {
        guard let token = authToken else {
            throw AuthError.invalidSession
        }
        
        if token.isExpired {
            try await refreshToken()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTokenRefresh() {
        // Refresh token 5 minutes before expiration
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                do {
                    try await self.validateSession()
                } catch {
                    await self.cleanupSession()
                }
            }
        }
    }
    
    private func restoreSession() {
        Task {
            do {
                if let savedToken: AuthToken = try await keychain.load(for: "authToken") {
                    authToken = savedToken
                    try await validateSession()
                    
                    if let savedUser: User = try await keychain.load(for: "currentUser") {
                        currentUser = savedUser
                        isAuthenticated = true
                        authStatePublisher.send(.authenticated(savedUser))
                    }
                }
            } catch {
                await cleanupSession()
            }
        }
    }
    
    private func cleanupSession() {
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        
        Task {
            try? await keychain.delete(for: "authToken")
            try? await keychain.delete(for: "currentUser")
        }
        
        authStatePublisher.send(.loggedOut)
    }
    
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func enableBiometrics(for username: String) async throws {
        // Implement biometric authentication
    }
    
    private func storeCredentials(_ credentials: AuthCredentials) async throws {
        try await keychain.save(credentials, for: "credentials")
    }
}

// MARK: - Supporting Types

struct AuthCredentials: Codable {
    let username: String
    let password: String
    let deviceInfo: DeviceInfo
}

struct DeviceInfo: Codable {
    let identifier: String
    let name: String
    let systemVersion: String
    
    static var current: DeviceInfo {
        DeviceInfo(
            identifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            name: UIDevice.current.name,
            systemVersion: UIDevice.current.systemVersion
        )
    }
}

struct AuthResponse: Codable {
    let token: AuthToken
    let user: User
}

// MARK: - Backend Communication

protocol BackendManagerProtocol {
    func sendRequest(
        endpoint: String,
        method: String,
        headers: [String: String]?,
        body: Encodable?
    ) async throws -> HTTPResponse
}

struct HTTPResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

struct HTTPError: Error {
    let statusCode: Int
    let message: String
}

class BackendManager: BackendManagerProtocol {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func sendRequest(
        endpoint: String,
        method: String = "GET",
        headers: [String: String]? = nil,
        body: Encodable? = nil
    ) async throws -> HTTPResponse {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw HTTPError(statusCode: -1, message: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError(statusCode: -1, message: "Invalid response")
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw HTTPError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        
        return HTTPResponse(
            data: data,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
        )
    }
}
