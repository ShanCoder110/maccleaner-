//
//  AppLegal.swift
//  mac_cleaner
//
//  Replace privacyPolicyURL with your hosted privacy page before App Store submission.
//  Terms defaults to Apple’s Standard Licensed Application EULA.
//

import Foundation

enum AppLegal {
    static let privacyPolicyURL = URL(string: "https://example.com/maccleaner-plus/privacy")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let supportEmail = "support@example.com"
}
