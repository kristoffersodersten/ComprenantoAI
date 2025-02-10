import Foundation
import os.log

enum BackendCommunicationError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int, Data?)
    case encodingError(Error)
    case decodingError(Error)
    case requestTimedOut
}

class UnifiedBackendManager {
    private let baseURL: String
    private let session: URLSession
    private let log = Logger(subsystem: "com.yourcompany.comprenanto", category: "BackendCommunication")

    init(baseURL: String) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    }

    func fetchData<T: Decodable>(
        endpoint: String,
        completion: @escaping (Result<T, BackendCommunicationError>) -> Void
    ) {
        guard let url = URL(string: "\(self.baseURL)/\(endpoint)") else {
            self.log.error("Invalid URL: \(self.baseURL)/\(endpoint)")
            completion(.failure(.invalidURL))
            return
        }

        let task = self.session.dataTask(with: url) { data, response, error in
            if let error = error as NSError? {
                if error.code == NSURLErrorTimedOut {
                    completion(.failure(.requestTimedOut))
                } else {
                    self.log.error("Network error: \(error)")
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                self.log.error("Invalid response: \(String(describing: response))")
                completion(.failure(.invalidResponse(-1, nil)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                self.log.error("Invalid response status code: \(httpResponse.statusCode)")
                completion(.failure(.invalidResponse(httpResponse.statusCode, data)))
                return
            }

            do {
                let decodedData = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedData))
            } catch {
                self.log.error("Decoding error: \(error)")
                completion(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }

    func sendData<T: Encodable>(
        endpoint: String,
        data: T,
        method: String = "POST",
        completion: @escaping (Result<Data, BackendCommunicationError>) -> Void
    ) {
        guard let url = URL(string: "\(self.baseURL)/\(endpoint)") else {
            self.log.error("Invalid URL: \(self.baseURL)/\(endpoint)")
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONEncoder().encode(data)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch {
            self.log.error("Encoding error: \(error)")
            completion(.failure(.encodingError(error)))
            return
        }

        let task = self.session.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                if error.code == NSURLErrorTimedOut {
                    completion(.failure(.requestTimedOut))
                } else {
                    self.log.error("Network error: \(error)")
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                self.log.error("Invalid response: \(String(describing: response))")
                completion(.failure(.invalidResponse(-1, nil)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                self.log.error("Invalid response status code: \(httpResponse.statusCode)")
                completion(.failure(.invalidResponse(httpResponse.statusCode, data)))
                return
            }

            completion(.success(data))
        }
        task.resume()
    }
}
