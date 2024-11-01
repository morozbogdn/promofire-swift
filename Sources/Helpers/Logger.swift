//
//  Logger.swift
//  promofire-swift
//
//  Created by Bogdan Moroz on 01.10.2024.
//

import Foundation
class PromofireLogger {
    static let shared = PromofireLogger()
    
    var isDebug: Bool = false
    
    private var requestCounter: Int = 0
    private var pendingRequests: [Int: (URLRequest, Date)] = [:]
    private var completedRequestIds: Set<Int> = []
    private let logQueue = DispatchQueue(label: "com.promofire.logger", qos: .utility)
    
    private init() {}
    
    func log(_ message: String, level: LogLevel = .info, error: Error? = nil) {
        guard isDebug else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var logMessage = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)"
        
        if let error = error {
            logMessage += "\n╭─ Error Details " + String(repeating: "─", count: 50)
            formatError(error)
                .split(separator: "\n")
                .forEach { line in
                    logMessage += "\n│ \(line)"
                }
            logMessage += "\n╰" + String(repeating: "─", count: 65)
        }
        
        print(logMessage)
    }
    
    func logRequest(_ request: URLRequest) -> Int {
        guard isDebug else { return 0 }
        
        return logQueue.sync {
            requestCounter += 1
            pendingRequests[requestCounter] = (request, Date())
            return requestCounter
        }
    }
    
    func logResponse(_ response: HTTPURLResponse?, data: Data?, error: Error?, for requestId: Int) {
        guard isDebug, requestId != -1 else { return }
        
        logQueue.async { [weak self] in
            guard let self = self,
                  !completedRequestIds.contains(requestId),
                  let (originalRequest, _) = pendingRequests[requestId] else {
                return
            }
            
            // Get the actual HTTP method from the original request
            let method = originalRequest.httpMethod?.uppercased() ?? "GET" // Default to GET if not specified
            let url = originalRequest.url?.absoluteString ?? "Unknown URL"
            
            var logMessage = """
            ┌─ \(method) \(url) ─────────────────────────────────
            │ Request:
            """
            
            // Always add Headers section, even if empty
            logMessage += "\n│ Headers:"
            if let headers = originalRequest.allHTTPHeaderFields, !headers.isEmpty {
                headers.forEach { key, value in
                    logMessage += "\n│   \(key): \(value)"
                }
            }
            
            if let body = originalRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                logMessage += "\n│ Body:"
                let formattedJson = self.formatJSON(bodyString)
                formattedJson.components(separatedBy: .newlines).forEach { line in
                    logMessage += "\n│   \(line)"
                }
            }
            
            logMessage += "\n│\n│ Response:"
            
            if let httpResponse = response {
                logMessage += "\n│ Status: \(httpResponse.statusCode)"
                logMessage += "\n│ Headers:"
                httpResponse.allHeaderFields.forEach { key, value in
                    logMessage += "\n│   \(key): \(value)"
                }
            }
            
            if let data = data {
                logMessage += "\n│ Body:"
                if let bodyString = String(data: data, encoding: .utf8) {
                    let formattedJson = self.formatJSON(bodyString)
                    formattedJson.components(separatedBy: .newlines).forEach { line in
                        logMessage += "\n│   \(line)"
                    }
                } else {
                    logMessage += "\n│   [Binary data of \(data.count) bytes]"
                }
            }
            
            if let error = error {
                logMessage += "\n│\n│ ❌ Error:"
                self.formatError(error).components(separatedBy: CharacterSet.newlines).forEach { line in
                    logMessage += "\n│   \(line)"
                }
            }
            
            logMessage += "\n└───────────────────────────────────────────────────"
            
            print(logMessage)
            
            pendingRequests.removeValue(forKey: requestId)
            completedRequestIds.insert(requestId)
        }
    }
    
    private func formatError(_ error: Error) -> String {
        switch error {
        case let decodingError as DecodingError:
            return "🔍 " + formatDecodingError(decodingError)
        case let errorResponse as ErrorResponse:
            return "🌐 " + formatErrorResponse(errorResponse)
        case let urlError as URLError:
            return "🔌 " + formatURLError(urlError)
        case let nsError as NSError:
            return """
                ⚠️ System Error
                Domain: \(nsError.domain)
                Code: \(nsError.code)
                Description: \(nsError.localizedDescription)
                Full error: \(error)
                Details: \(nsError.userInfo)
                """
        default:
            return """
                ⚠️ Unexpected Error
                Type: \(type(of: error))
                Description: \(error.localizedDescription)
                Full error: \(error)
                """
        }
    }
    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return """
                Decoding Error - Data Corrupted
                Path: \(formatCodingPath(context.codingPath))
                Details: \(context.debugDescription)
                """
        case .keyNotFound(let key, let context):
            return """
                Decoding Error - Missing Key '\(key.stringValue)'
                Path: \(formatCodingPath(context.codingPath))
                Details: \(context.debugDescription)
                """
        case .typeMismatch(let type, let context):
            return """
                Decoding Error - Type Mismatch
                Expected Type: \(type)
                Path: \(formatCodingPath(context.codingPath))
                Details: \(context.debugDescription)
                """
        case .valueNotFound(let type, let context):
            return """
                Decoding Error - Null Value
                Expected Type: \(type)
                Path: \(formatCodingPath(context.codingPath))
                Details: \(context.debugDescription)
                """
        @unknown default:
            return "Unknown Decoding Error: \(error)"
        }
    }
    
    private func formatCodingPath(_ path: [CodingKey]) -> String {
        path.map {
            if let intValue = $0.intValue {
                return "[\(intValue)]"
            }
            return $0.stringValue
        }.joined(separator: " → ")
    }
    
    private func formatErrorResponse(_ error: ErrorResponse) -> String {
        switch error {
        case .error(let code, _, let response, let underlyingError):
            var message = "API Error (Code: \(code))"
            
            if let httpResponse = response as? HTTPURLResponse {
                message += "\nHTTP Status: \(httpResponse.statusCode)"
            }
            
            if let decodingError = underlyingError as? DecodingError {
                message += "\n\n"
                message += formatDecodingError(decodingError)
            } else {
                message += "\nUnderlying Error: \(underlyingError)"
            }
            
            return message
        }
    }
    
    private func formatURLError(_ error: URLError) -> String {
        return """
            Network Error [\(error.code.rawValue)]
            Description: \(error.localizedDescription)
            Full error: \(error)
            URL: \(error.failureURLString ?? "N/A")
            """
    }
    
    func logError(_ request: URLRequest, error: Error, statusCode: Int? = nil) {
        guard isDebug else { return }
        
        logQueue.sync {
            let method = request.httpMethod?.uppercased() ?? "GET"
            let url = request.url?.absoluteString ?? "Unknown URL"
            
            var logMessage = """
                ┌─ ❌ Error in \(method) \(url)
                """
            
            if let statusCode = statusCode {
                logMessage += " (Status: \(statusCode))"
            }
            
            logMessage += "\n│"
            formatError(error).components(separatedBy: CharacterSet.newlines).forEach { line in
                logMessage += "\n│ \(line)"
            }
            logMessage += "\n└───────────────────────────────────"
            
            print(logMessage)
        }
    }
    
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
    
    enum LogLevel: String {
        case debug, info, warning, error
    }
}

public enum PromoFireError: Error {
    case notConfigured
}

struct BackendError: LocalizedError {
    let errorType: String
    let message: String
    let statusCode: Int
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return errorType
    }
}

extension ErrorResponse: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .error(_, _, _, let error):
            if let backendError = error as? BackendError {
                return "\(backendError.errorType): \(backendError.message)"
            }
            return error.localizedDescription
        }
    }
}
