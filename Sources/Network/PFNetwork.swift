//
//  PFNetwork.swift
//
//
//  Created by Bogdan Moroz on 01.11.2024.
//

import Foundation

class LoggingURLSession: URLSessionProtocol {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func dataTaskFromProtocol(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        return session.dataTask(with: request, completionHandler: completionHandler)
    }
}

class LoggingURLSessionRequestBuilderFactory: RequestBuilderFactory {
    func getNonDecodableBuilder<T>() -> RequestBuilder<T>.Type {
        return LoggingURLSessionRequestBuilder<T>.self
    }
    
    func getBuilder<T: Decodable>() -> RequestBuilder<T>.Type {
        return LoggingURLSessionDecodableRequestBuilder<T>.self
    }
}

class LoggingURLSessionRequestBuilder<T>: URLSessionRequestBuilder<T> {
    override func createURLSession() -> URLSessionProtocol {
        return LoggingURLSession(session: super.createURLSession() as! URLSession)
    }
    
    private func createRequestForLogging() -> URLRequest {
        var request = URLRequest(url: URL(string: URLString)!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        
        if let parameters = parameters {
            if let jsonData = parameters["jsonData"] as? Data {
                request.httpBody = jsonData
            } else {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                    request.httpBody = jsonData
                } catch {
                    print("Failed to encode parameters: \(error)")
                }
            }
        }
        
        return request
    }
    
    @discardableResult
    override func execute(_ apiResponseQueue: DispatchQueue = OpenAPIClientAPI.apiResponseQueue, _ completion: @escaping (_ result: Swift.Result<Response<T>, ErrorResponse>) -> Void) -> RequestTask {
        let request = createRequestForLogging()
        let requestId = PromofireLogger.shared.logRequest(request)
        
        return super.execute(apiResponseQueue) { result in
            switch result {
            case .success(let response):
                let responseData: Data?
                if let bodyData = response.body as? Data {
                    responseData = bodyData
                } else if let encodableBody = response.body as? Encodable,
                          let jsonData = try? JSONEncoder().encode(encodableBody) {
                    responseData = jsonData
                } else {
                    responseData = nil
                }
                
                let httpResponse = HTTPURLResponse(
                    url: URL(string: self.URLString)!,
                    statusCode: response.statusCode,
                    httpVersion: nil,
                    headerFields: response.header
                )
                
                PromofireLogger.shared.logResponse(
                    httpResponse,
                    data: responseData,
                    error: nil,
                    for: requestId
                )
            case .failure(let errorResponse):
                if case .error(_, let data, let response, let error) = errorResponse {
                    PromofireLogger.shared.logResponse(
                        response as? HTTPURLResponse,
                        data: data,
                        error: error,
                        for: requestId
                    )
                }
            }
            completion(result)
        }
    }
    
    override func execute() async throws -> Response<T> {
        let request = createRequestForLogging()
        let requestId = PromofireLogger.shared.logRequest(request)
        
        do {
            let response = try await super.execute()
            let responseData: Data?
            if let bodyData = response.body as? Data {
                responseData = bodyData
            } else if let encodableBody = response.body as? Encodable,
                      let jsonData = try? JSONEncoder().encode(encodableBody) {
                responseData = jsonData
            } else {
                responseData = nil
            }
            
            let httpResponse = HTTPURLResponse(
                url: URL(string: self.URLString)!,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: response.header
            )
            
            PromofireLogger.shared.logResponse(
                httpResponse,
                data: responseData,
                error: nil,
                for: requestId
            )
            return response
        } catch {
            if let errorResponse = error as? ErrorResponse,
               case .error(_, let data, let response, let underlyingError) = errorResponse {
                PromofireLogger.shared.logResponse(
                    response as? HTTPURLResponse,
                    data: data,
                    error: underlyingError,
                    for: requestId
                )
            } else {
                PromofireLogger.shared.logResponse(
                    nil,
                    data: nil,
                    error: error,
                    for: requestId
                )
            }
            throw error
        }
    }
}

class LoggingURLSessionDecodableRequestBuilder<T: Decodable>: URLSessionDecodableRequestBuilder<T> {
    override func createURLSession() -> URLSessionProtocol {
        return LoggingURLSession(session: super.createURLSession() as! URLSession)
    }
    
    private func createRequestForLogging() -> URLRequest {
        var request = URLRequest(url: URL(string: URLString)!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        
        if let parameters = parameters {
            if let jsonData = parameters["jsonData"] as? Data {
                request.httpBody = jsonData
            } else {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                    request.httpBody = jsonData
                } catch {
                    print("Failed to encode parameters: \(error)")
                }
            }
        }
        
        return request
    }
    
    @discardableResult
    override func execute(_ apiResponseQueue: DispatchQueue = OpenAPIClientAPI.apiResponseQueue, _ completion: @escaping (_ result: Swift.Result<Response<T>, ErrorResponse>) -> Void) -> RequestTask {
        return super.execute(apiResponseQueue) { result in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let errorResponse):
                if case .error(let code, let data, let response, _) = errorResponse,
                   let bodyData = data,
                   let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let errorString = json["error"] as? String,
                   let message = json["message"] as? String,
                   !errorString.isEmpty && !message.isEmpty {
                    
                    let backendError = BackendError(
                        errorType: errorString,
                        message: message,
                        statusCode: json["statusCode"] as? Int ?? code
                    )
                    
                    completion(.failure(.error(
                        code,
                        data,
                        response,
                        backendError
                    )))
                } else {
                    completion(.failure(errorResponse))
                }
            }
        }
    }
    
    override func execute() async throws -> Response<T> {
        let request = createRequestForLogging()
        let requestId = PromofireLogger.shared.logRequest(request)
        
        do {
            let response = try await super.execute()
            let httpResponse = HTTPURLResponse(
                url: URL(string: self.URLString)!,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: response.header
            )
            
            PromofireLogger.shared.logResponse(
                httpResponse,
                data: response.bodyData,
                error: nil,
                for: requestId
            )
            
            return response
        } catch {
            if let errorResponse = error as? ErrorResponse,
               case .error(let code, let data, let response, _) = errorResponse,
               let bodyData = data,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let errorString = json["error"] as? String,
               let message = json["message"] as? String,
               !errorString.isEmpty && !message.isEmpty {
                
                let backendError = BackendError(
                    errorType: errorString,
                    message: message,
                    statusCode: json["statusCode"] as? Int ?? code
                )
                
                PromofireLogger.shared.logResponse(
                    response as? HTTPURLResponse,
                    data: data,
                    error: backendError,
                    for: requestId
                )
                
                throw ErrorResponse.error(code, data, response, backendError)
            }
            
            if let errorResponse = error as? ErrorResponse,
               case .error(_, let data, let response, let underlyingError) = errorResponse {
                PromofireLogger.shared.logResponse(
                    response as? HTTPURLResponse,
                    data: data,
                    error: underlyingError,
                    for: requestId
                )
            }
            throw error
        }
    }
}
