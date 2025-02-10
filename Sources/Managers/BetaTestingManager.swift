import Foundation
import SwiftUI
import os.log

enum BetaTestingError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case encodingError(Error)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feedback submission URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let code):
            return "Server error with code: \(code)"
        case .encodingError(let error):
            return "Data encoding error: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}

@MainActor
class BetaTestingManager: ObservableObject {
    static let shared = BetaTestingManager()
    
    private let backendURL: String
    private let session: URLSession
    private let log = Logger(subsystem: "com.comprenanto", category: "BetaTesting")
    
    @Published private(set) var isSubmitting = false
    @Published private(set) var lastSubmissionDate: Date?
    @Published var recentFeedback: [Feedback] = []
    
    // MARK: - Types
    
    struct Feedback: Codable, Identifiable {
        let id: UUID
        let user: String
        let content: String
        let category: Category
        let timestamp: Date
        var screenshot: Data?
        var metadata: [String: String]
        
        enum Category: String, Codable, CaseIterable {
            case bug = "Bug Report"
            case feature = "Feature Request"
            case improvement = "Improvement"
            case other = "Other"
        }
    }
    
    // MARK: - Initialization
    
    private init(
        backendURL: String = ProcessInfo.processInfo.environment["FEEDBACK_URL"] ?? "https://api.comprenanto.com/feedback",
        session: URLSession = .shared
    ) {
        self.backendURL = backendURL
        self.session = session
    }
    
    // MARK: - Public Methods
    
    func submitFeedback(
        _ feedback: Feedback
    ) async throws {
        guard let url = URL(string: backendURL) else {
            throw BetaTestingError.invalidURL
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(feedback)
        } catch {
            log.error("Failed to encode feedback: \(error.localizedDescription)")
            throw BetaTestingError.encodingError(error)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BetaTestingError.invalidResponse(-1)
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw BetaTestingError.invalidResponse(httpResponse.statusCode)
            }
            
            lastSubmissionDate = Date()
            recentFeedback.append(feedback)
            
            log.info("Successfully submitted feedback: \(feedback.id)")
            
        } catch let error as BetaTestingError {
            throw error
        } catch {
            log.error("Network error: \(error.localizedDescription)")
            throw BetaTestingError.networkError(error)
        }
    }
    
    func captureScreenshot() -> Data? {
        guard let window = UIApplication.shared.windows.first else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let screenshot = renderer.pngData { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return screenshot
    }
}

// MARK: - SwiftUI Views

struct FeedbackForm: View {
    @StateObject private var betaManager = BetaTestingManager.shared
    @State private var feedback = ""
    @State private var category: BetaTestingManager.Feedback.Category = .bug
    @State private var includeScreenshot = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Feedback Details")) {
                Picker("Category", selection: $category) {
                    ForEach(BetaTestingManager.Feedback.Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                
                TextEditor(text: $feedback)
                    .frame(height: 100)
                
                Toggle("Include Screenshot", isOn: $includeScreenshot)
            }
            
            Section {
                Button(action: submitFeedback) {
                    if betaManager.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Submit Feedback")
                    }
                }
                .disabled(feedback.isEmpty || betaManager.isSubmitting)
            }
        }
        .navigationTitle("Submit Feedback")
        .alert("Feedback Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitFeedback() {
        Task {
            do {
                let newFeedback = BetaTestingManager.Feedback(
                    id: UUID(),
                    user: "current_user", // Replace with actual user ID
                    content: feedback,
                    category: category,
                    timestamp: Date(),
                    screenshot: includeScreenshot ? betaManager.captureScreenshot() : nil,
                    metadata: ["device": UIDevice.current.model]
                )
                
                try await betaManager.submitFeedback(newFeedback)
                
                alertMessage = "Feedback submitted successfully!"
                showAlert = true
                feedback = ""
                
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

struct RecentFeedbackView: View {
    @StateObject private var betaManager = BetaTestingManager.shared
    
    var body: some View {
        List(betaManager.recentFeedback) { feedback in
            VStack(alignment: .leading, spacing: 8) {
                Text(feedback.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(feedback.content)
                    .font(.body)
                
                Text(feedback.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Recent Feedback")
        .emptyState(betaManager.recentFeedback.isEmpty) {
            Text("No feedback submitted yet")
        }
    }
}

extension View {
    func emptyState<Content: View>(
        _ isEmpty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            self
            if isEmpty {
                content()
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedbackForm()
    }
}
