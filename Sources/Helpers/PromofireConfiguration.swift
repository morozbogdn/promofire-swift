//
//  PromofireConfiguration.swift
//  promofire-swift
//
//  Created by Bogdan Moroz on 01.10.2024.
//
import Foundation

extension Promofire {
    internal actor ConfigurationState {
        private var operations: [(operation: () async throws -> Any, completion: (Result<Any, Error>) -> Void)] = []
        private var isConfiguring = false
        
        func add<T>(_ operation: @escaping () async throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
            let wrapped: (Result<Any, Error>) -> Void = { result in
                switch result {
                case .success(let value):
                    completion(.success(value as! T))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            operations.append((
                operation: { try await operation() },
                completion: wrapped
            ))
        }
        
        func executeAll() {
            let currentOperations = operations
            operations.removeAll()
            
            for op in currentOperations {
                Task {
                    do {
                        let result = try await op.operation()
                        op.completion(.success(result))
                    } catch {
                        op.completion(.failure(error))
                    }
                }
            }
        }
        
        func cancelAll(with error: Error) {
            let currentOperations = operations
            operations.removeAll()
            currentOperations.forEach { $0.completion(.failure(error)) }
        }
    }
    
    func withConfiguration<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        if isConfigured {
            return try await operation()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await state.add(operation) { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                guard let task = configurationTask else {
                    await state.cancelAll(with: PromoFireError.notConfigured)
                    return
                }
                
                do {
                    try await task.value
                    if !isConfigured {
                        await state.cancelAll(with: PromoFireError.notConfigured)
                    }
                } catch {
                    await state.cancelAll(with: error)
                }
            }
        }
    }
    
    internal func validateExistingConfiguration() async throws {
        let templates = try await CodeTemplatesAPI.codeTemplatesControllerGetMany(limit: 1, offset: 0)
        _isCodeGenerationAvailable = !templates.templates.isEmpty
    }
    
    internal func performInitialConfiguration(secret: String, userInfo: UserInfo?) async throws {
        let authResult = try await AuthAPI.authControllerSignInViaSdk(
            sdkAuthResuestPayload: .init(secret: secret)
        )
        saveToken(authResult.accessToken)
        
        let customersResult = try await CustomersAPI.customersControllerCreatePreset(
            createCustomerPresetRequestDto: .init(platform: .ios)
        )
        saveToken(customersResult.accessToken)
        
        let result = try await CustomersAPI.customersControllerUpsert(
            createCustomerRequestDto: DeviceDataCollector.createCustomerRequest(userInfo)
        )
        saveToken(result.accessToken)
        
        let templates = try await CodeTemplatesAPI.codeTemplatesControllerGetMany(limit: 1, offset: 0)
        _isCodeGenerationAvailable = !templates.templates.isEmpty
    }
    
    internal func configureSDK(secret: String, userInfo: UserInfo? = nil) async throws {
        guard !isConfigured else { return }
        
        do {
            try await performInitialConfiguration(secret: secret, userInfo: userInfo)
            isConfigured = true
            await state.executeAll()
        } catch {
            isConfigured = false
            await state.cancelAll(with: error)
            throw error
        }
    }
}
