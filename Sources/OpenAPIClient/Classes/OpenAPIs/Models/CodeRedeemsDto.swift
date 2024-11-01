//
// CodeRedeemsDto.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation
#if canImport(AnyCodable)
import AnyCodable
#endif

public final class CodeRedeemsDto: Codable, JSONEncodable, Hashable {

    static let totalRule = NumericRule<Int>(minimum: 0, exclusiveMinimum: false, maximum: nil, exclusiveMaximum: false, multipleOf: nil)
    public var redeems: [CodeRedeemDto]
    public var total: Int

    public init(redeems: [CodeRedeemDto], total: Int) {
        self.redeems = redeems
        self.total = total
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case redeems
        case total
    }

    // Encodable protocol methods

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(redeems, forKey: .redeems)
        try container.encode(total, forKey: .total)
    }

    public static func == (lhs: CodeRedeemsDto, rhs: CodeRedeemsDto) -> Bool {
        lhs.redeems == rhs.redeems &&
        lhs.total == rhs.total
        
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(redeems.hashValue)
        hasher.combine(total.hashValue)
        
    }
}

