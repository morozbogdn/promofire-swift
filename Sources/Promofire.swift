//
//  Promofire.swift
//
//
//  Created by Bogdan Moroz on 01.10.2024.
//
import Foundation

public class Promofire {
    public static let shared = Promofire()
    public var isDebug = false { didSet { PromofireLogger.shared.isDebug = isDebug } }
    
    internal var isConfigured = false
    internal var _isCodeGenerationAvailable: Bool = false
    
    internal let state = ConfigurationState()
    internal var configurationTask: Task<Void, Error>?
    internal var pendingTasks: [(Any, Any)] = []
    
    private init() {
        //TEST
        //OpenAPIClientAPI.basePath = "https://api.promofire.io"
        //PROD
        OpenAPIClientAPI.basePath = "https://api.stage.promofire.io"
    }
    
    public func configure(secret: String, userInfo: UserInfo? = nil) {
        OpenAPIClientAPI.requestBuilderFactory = LoggingURLSessionRequestBuilderFactory()
        configurationTask = Task { try await configureSDK(secret: secret, userInfo: userInfo) }
    }
    
    public func isCodeGenerationAvailable() async -> Bool {
        if let task = configurationTask {
            do {
                try await task.value
            } catch {
                return false
            }
        }
        return _isCodeGenerationAvailable
    }
    
    public func getCurrentUserCodes(limit: Int, offset: Int) async throws -> CodesDto {
        try await withConfiguration {
            try await CodesAPI.codesControllerGetOwn(limit: limit, offset: offset)
        }
    }
    
    public func getCurrentUserRedeems(limit: Int, offset: Int, from: Date, to: Date, codeValue: String? = nil) async throws -> CodeRedeemsDto  {
        try await withConfiguration {
            try await CodesAPI.codesControllerGetSelfRedeems(limit: limit, offset: offset, from: ISODateFormatter.string(from: from), to: ISODateFormatter.string(from: to))
        }
    }
    
    public func getChampaigns(limit: Int, offset: Int) async throws -> CodeTemplatesDto {
        try await withConfiguration {
            try await CodeTemplatesAPI.codeTemplatesControllerGetMany(limit: limit, offset: offset)
        }
    }
    
    public func getChampaignBy(id: UUID) async throws -> CodeTemplateDto {
        try await withConfiguration {
            try await CodeTemplatesAPI.codeTemplatesControllerGetOne(id: id.uuidString)
        }
    }
    
    public func generateCode(value: String, templateId: UUID, payload: [String: Any?]) async throws -> CodeDto {
        try await withConfiguration {
            try await CodesAPI.codesControllerCreate(createCodeRequestDto: .init(value: value, templateId: templateId, payload: AnyCodable(payload)))
        }
    }
    
    public func generateCodes(_ params: CreateCodesRequestDto) async throws -> [CodeDto] {
        try await withConfiguration {
            try await CodesAPI.codesControllerCreateMany(createCodesRequestDto: params)
        }
    }
    
    public func redeemCode(codeValue: String) async throws {
        try await withConfiguration {
            try await CodesAPI.codesControllerRedeem(redeemCodeRequestDto: .init(codeValue: codeValue, platform: .ios))
        }
    }
    
    public func getCurrentUser() async throws -> CustomerDto {
        try await withConfiguration {
            try await CustomersAPI.customersControllerGetSelf()
        }
    }
    
    public func updateCurrentUser(_ params: UpdateCustomerSelfDto) async throws -> CustomerDto {
        try await withConfiguration {
            try await CustomersAPI.customersControllerUpdateSelf(updateCustomerSelfDto: params)
        }
    }
    
    public func getCodeRedeems(limit: Int, offset: Int, from: Date, to: Date, codeValue: String? = nil, redeemerId: UUID? = nil) async throws -> CodeRedeemsDto {
        try await withConfiguration {
            try await CodesAPI.codesControllerGetRedeems(limit: limit, offset: offset, from: ISODateFormatter.string(from: from), to: ISODateFormatter.string(from: to), codeValue: codeValue, redeemerId: redeemerId)
        }
    }
}
