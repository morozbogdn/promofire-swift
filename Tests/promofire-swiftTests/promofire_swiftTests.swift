import XCTest
@testable import promofire_swift

/// Integration Test Suite for Promofire SDK
/// Test Coverage:
/// - SDK Configuration
///   - Initial setup with valid/invalid credentials
///   - User info handling
/// - User Operations
///   - Getting current user
///   - Updating user information
///   - User codes retrieval
///   - User redeems history
/// - Campaign Management
///   - Listing available campaigns
///   - Retrieving specific campaign details
/// - Code Operations
///   - Code generation (single and batch)
///   - Code validation
///   - Code redemption
///   - Code redemption history
/// - Date Range Operations
///   - Historical data retrieval
///   - Date filtering for redeems
class PromofireIntegrationTests: XCTestCase {
    // MARK: - Properties
    var sut: Promofire!
    let secret = "77c00df8aa736122375090361d0388dffb5d550cc334b6f80e768a8579c71f02"
    let userInfo = UserInfo(
        customerUserId: "testId",
        firstName: "test",
        lastName: "test",
        email: "test@gmail.com",
        phone: "+380939311111"
    )
    
    // Date range for testing
    let fromDate = Calendar.current.date(from: DateComponents(year: 2020))!
    let toDate = Date()
    
    // MARK: - Test Lifecycle
    override func setUp() async throws {
        try await super.setUp()
        sut = Promofire.shared
        sut.isDebug = true
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    func testSDKConfiguration() async throws {
        // When
        sut.configure(secret: secret, userInfo: userInfo)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Then
        let isAvailable = await sut.isCodeGenerationAvailable()
        XCTAssertTrue(isAvailable, "Code generation should be available after successful configuration")
    }
    
    // MARK: - User Management Tests
    func testGetCurrentUser() async throws {
        // Given
        try await configureSDK()
        
        // When
        let user = try await sut.getCurrentUser()
        
        // Then
        XCTAssertNotNil(user, "Should retrieve user information")
        XCTAssertEqual(user.email, userInfo.email, "Retrieved user should match configured user")
    }
    
    func testUpdateCurrentUser() async throws {
        // Given
        try await configureSDK()
        let newFirstName = "updatedTest"
        
        // When
        let updatedUser = try await sut.updateCurrentUser(.init(firstName: newFirstName))
        
        // Then
        XCTAssertEqual(updatedUser.firstName, newFirstName, "User's first name should be updated")
    }
    
    // MARK: - Campaign Tests
    func testGetCampaigns() async throws {
        // Given
        try await configureSDK()
        
        // When
        let campaigns = try await sut.getChampaigns(limit: 10, offset: 0)
        
        // Then
        XCTAssertNotNil(campaigns, "Should retrieve campaigns")
        XCTAssertFalse(campaigns.templates.isEmpty, "Should have at least one campaign")
    }
    
    func testGetSpecificCampaign() async throws {
        // Given
        try await configureSDK()
        let campaigns = try await sut.getChampaigns(limit: 10, offset: 0)
        guard let campaignId = campaigns.templates.first?.id else {
            XCTFail("No campaigns available for testing")
            return
        }
        
        // When
        let campaign = try await sut.getChampaignBy(id: campaignId)
        
        // Then
        XCTAssertNotNil(campaign, "Should retrieve specific campaign")
        XCTAssertEqual(campaign.id, campaignId, "Retrieved campaign should match requested ID")
    }
    
    // MARK: - Code Generation Tests
    func testGenerateSingleCode() async throws {
        // Given
        try await configureSDK()
        let campaignId = try await getActiveCampaignId()
        let codeValue = UUID().uuidString
        
        // When
        let code = try await sut.generateCode(
            value: codeValue,
            templateId: campaignId,
            payload: ["test": 42]
        )
        
        // Then
        XCTAssertEqual(code.value, codeValue, "Generated code should match requested value")
        XCTAssertTrue(code.isValid, "Generated code should be valid")
    }
    
    func testGenerateMultipleCodes() async throws {
        // Given
        try await configureSDK()
        let campaignId = try await getActiveCampaignId()
        let codeCount: Double = 10
        
        // When
        let codes = try await sut.generateCodes(.init(
            templateId: campaignId,
            payload: ["test": 42],
            count: codeCount
        ))
        
        // Then
        XCTAssertEqual(codes.count, Int(codeCount), "Should generate requested number of codes")
        XCTAssertTrue(codes.allSatisfy { $0.isValid }, "All generated codes should be valid")
    }
    
    // MARK: - Code Redemption Tests
    func testCodeRedemption() async throws {
        // Given
        try await configureSDK()
        let campaignId = try await getActiveCampaignId()
        let code = try await sut.generateCode(
            value: UUID().uuidString,
            templateId: campaignId,
            payload: ["test": 42]
        )
        
        // When/Then
        do {
            try await sut.redeemCode(codeValue: code.value)
            // If we reach here, the test passed
        } catch {
            XCTFail("Code redemption failed with error: \(error)")
        }
    }
    
    func testCodeRedemptionWithInvalidCode() async throws {
       // Given
       try await configureSDK()
       let invalidCode = "INVALID_CODE_\(UUID().uuidString)"
       
       // When/Then
       do {
           try await sut.redeemCode(codeValue: invalidCode)
           XCTFail("Code redemption should fail with invalid code")
       } catch {
           XCTAssertTrue(true)
       }
    }
    
    // MARK: - History Tests
    func testGetUserCodes() async throws {
        // Given
        try await configureSDK()
        
        // When
        let codes = try await sut.getCurrentUserCodes(limit: 10, offset: 0)
        
        // Then
        XCTAssertNotNil(codes, "Should retrieve user codes history")
    }
    
    func testGetUserRedeems() async throws {
        // Given
        try await configureSDK()
        
        // When
        let redeems = try await sut.getCurrentUserRedeems(
            limit: 10,
            offset: 0,
            from: fromDate,
            to: toDate
        )
        
        // Then
        XCTAssertNotNil(redeems, "Should retrieve user redeems history")
    }
    
    func testGetCodeRedeems() async throws {
        // Given
        try await configureSDK()
        
        // When
        let redeems = try await sut.getCodeRedeems(
            limit: 10,
            offset: 0,
            from: fromDate,
            to: toDate
        )
        
        // Then
        XCTAssertNotNil(redeems, "Should retrieve code redeems history")
    }
    
    // MARK: - Helper Methods
    private func configureSDK() async throws {
        sut.configure(secret: secret, userInfo: userInfo)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        guard await sut.isCodeGenerationAvailable() else {
            throw NSError(domain: "PromofireTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "SDK configuration failed"
            ])
        }
    }
    
    private func getActiveCampaignId() async throws -> UUID {
        let campaigns = try await sut.getChampaigns(limit: 10, offset: 0)
        guard let activeCampaign = campaigns.templates.first(where: { $0.status == .active }) else {
            throw NSError(domain: "PromofireTests", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "No active campaigns available"
            ])
        }
        return activeCampaign.id
    }
}
