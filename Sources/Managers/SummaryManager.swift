import Foundation
import EventKit
import os.log

enum SummaryManagerError: Error {
    case apiError(Error)
    case invalidResponse(Int)
    case encodingError(Error)
    case missingData
    case invalidApiKey
    case summaryGenerationFailed(Error)
    case eventCreationFailed(Error)
}

class SummaryManager {
    private let apiKey: String
    private let apiBaseUrl = "https://api.openai.com/v1/chat/completions"
    private let session = URLSession(configuration: .default)
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "SummaryManager")

    init(apiKey: String) {
        guard !apiKey.isEmpty else { fatalError("API key cannot be empty") }
        self.apiKey = apiKey
    }

    func generateSummary(
        from conversation: String,
        completion: @escaping (Result<String, SummaryManagerError>) -> Void
    ) {
        guard let url = URL(string: apiBaseUrl) else {
            completion(.failure(.apiError(NSError(domain: "InvalidURL", code: -1, userInfo: nil))))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that summarizes conversations."],
                ["role": "user", "content": conversation]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            log.error("Error encoding payload: \(error.localizedDescription)")
            completion(.failure(.encodingError(error)))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, completion: completion)
        }
        task.resume()
    }

    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<String, SummaryManagerError>) -> Void
    ) {
        if let error = error {
            self.log.error("API request failed: \(error.localizedDescription)")
            completion(.failure(.apiError(error)))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            self.log.error("Invalid response")
            completion(.failure(.invalidResponse(-1)))
            return
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            self.log.error("API request failed with status code: \(httpResponse.statusCode)")
            completion(.failure(.invalidResponse(httpResponse.statusCode)))
            return
        }

        guard let data = data else {
            self.log.error("Missing data in response")
            completion(.failure(.missingData))
            return
        }

        self.parseResponseData(data, completion: completion)
    }

    private func parseResponseData(
        _ data: Data,
        completion: @escaping (Result<String, SummaryManagerError>) -> Void
    ) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                completion(.success(content))
            } else {
                throw NSError(domain: "JSONError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid JSON response"
                ])
            }
        } catch {
            self.log.error("Error decoding JSON response: \(error.localizedDescription)")
            completion(.failure(.summaryGenerationFailed(error)))
        }
    }

    func createToDo(
        from summary: String,
        title: String,
        completion: @escaping (Result<Void, SummaryManagerError>) -> Void
    ) {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents(completion: { granted, error in
            if granted {
                self.createEvent(eventStore: eventStore, summary: summary, title: title, completion: completion)
            } else if let error = error {
                self.log.error("Calendar access denied: \(error.localizedDescription)")
                completion(.failure(.eventCreationFailed(error)))
            } else {
                completion(.failure(.eventCreationFailed(
                    NSError(
                        domain: "CalendarError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"]
                    )
                )))
            }
        })
    }

    private func createEvent(
        eventStore: EKEventStore,
        summary: String,
        title: String,
        completion: @escaping (Result<Void, SummaryManagerError>) -> Void
    ) {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = summary
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.startDate = Date()
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)

        do {
            try eventStore.save(event, span: .thisEvent)
            completion(.success(()))
        } catch {
            self.log.error("Event creation failed: \(error.localizedDescription)")
            completion(.failure(.eventCreationFailed(error)))
        }
    }
}
