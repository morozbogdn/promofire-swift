//
//  SystemDataCollector.swift
//  promofire-swift
//
//  Created by Bogdan Moroz on 01.10.2024.
//

import Foundation
import UIKit
import SystemConfiguration

public struct UserInfo {
    var customerUserId: String?
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    
    public init(customerUserId: String? = nil, firstName: String? = nil, lastName: String? = nil, email: String? = nil, phone: String? = nil) {
        self.customerUserId = customerUserId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
    }
}

internal class DeviceDataCollector {
    
    static func createCustomerRequest(_ userInfo: UserInfo?) -> CreateCustomerRequestDto {
        return CreateCustomerRequestDto(
            platform: .ios,
            device: getCurrentDevice(),
            os: getCurrentOSVersion(),
            appBuild: getAppBuild(),
            appVersion: getAppVersion(),
            sdkVersion: getSDKVersion(),
            tenantAssignedId: userInfo?.customerUserId,
            firstName: userInfo?.firstName,
            lastName: userInfo?.lastName,
            email: userInfo?.email,
            phone: userInfo?.phone
        )
    }
    
    private static func getCurrentDevice() -> String {
        return UIDevice.current.model
    }
    
    private static func getCurrentOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private static func getAppVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private static func getAppBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    private static func getSDKVersion() -> String {
        return SDKVersion.current
    }
}
