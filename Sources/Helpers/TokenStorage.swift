//
//  File.swift
//  promofire-swift
//
//  Created by Bogdan Moroz on 30.12.2024.
//

import Foundation

internal class TokenStorage {
    static let shared = TokenStorage()
    
    private let tokenKey = "promofire_access_token"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func saveToken(_ token: String) {
        userDefaults.set(token, forKey: tokenKey)
    }
    
    func getToken() -> String? {
        return userDefaults.string(forKey: tokenKey)
    }
    
    func clearToken() {
        userDefaults.removeObject(forKey: tokenKey)
    }
}

extension Promofire {
    internal func saveToken(_ token: String) {
        TokenStorage.shared.saveToken(token)
        OpenAPIClientAPI.customHeaders["Authorization"] = "Bearer \(token)"
    }
    
    public func logout() {
        TokenStorage.shared.clearToken()
        OpenAPIClientAPI.customHeaders.removeValue(forKey: "Authorization")
        isConfigured = false
        _isCodeGenerationAvailable = false
    }
}
