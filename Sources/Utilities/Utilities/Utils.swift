import Foundation
import CryptoKit
import os.log

class Utils {
    static let logger = Logger(subsystem: "com.comprenanto", category: "Utils")
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func calculateHash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func validateEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
    
    static func sanitizeInput(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func logError(_ error: Error, function: String = #function) {
        logger.error("\(function): \(error.localizedDescription)")
    }
    
    static func logInfo(_ message: String, function: String = #function) {
        logger.info("\(function): \(message)")
    }
}

extension Data {
    func prettyPrintedJSONString() -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return prettyPrintedString
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
