//
// AuthResponsePayload.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation
#if canImport(AnyCodable)
import AnyCodable
#endif

public final class AuthResponsePayload: Codable, JSONEncodable, Hashable {

    public var accessToken: String

    public init(accessToken: String) {
        self.accessToken = accessToken
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case accessToken
    }

    // Encodable protocol methods

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
    }

    public static func == (lhs: AuthResponsePayload, rhs: AuthResponsePayload) -> Bool {
        lhs.accessToken == rhs.accessToken
        
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(accessToken.hashValue)
        
    }
}

