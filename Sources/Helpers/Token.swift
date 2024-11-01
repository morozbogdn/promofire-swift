//
//  Token.swift
//
//
//  Created by Bogdan Moroz on 01.10.2024.
//

import Foundation
extension Promofire {
    internal func saveToken(_ token: String) {
        OpenAPIClientAPI.customHeaders["Authorization"] = "Bearer \(token)"
    }
}
