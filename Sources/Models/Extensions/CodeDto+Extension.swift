//
//  CodeDto+Extension.swift
//
//
//  Created by Bogdan Moroz on 30.10.2024.
//

import Foundation

public extension CodeDto {
    var isValid: Bool {
        return isValidByAmount && !isExpired && status == .active
    }
    
    private var isInfiniteCode: Bool {
        amount.lowercased() == "Infinity".lowercased()
    }
    
    private var isExpired: Bool {
        let currentTimeSeconds = Int(Date().timeIntervalSince1970)
        return currentTimeSeconds >= expiresAt
    }
    
    private var amountValue: Int? {
        guard !isInfiniteCode else { return nil }
        return Int(amount)
    }
    
    private var isValidByAmount: Bool {
        if isInfiniteCode {
            return true
        } else {
            return (amountValue ?? 0) > 0
        }
    }
}
