//
//  AppLegalTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct AppLegalTests {
    @Test func supportEmailIsNotAPlaceholder() {
        #expect(!AppLegal.supportEmail.contains("example.com"))
        #expect(AppLegal.supportEmail.contains("@"))
        #expect(AppLegal.supportMailtoURL.scheme == "mailto")
    }

    @Test func hostedPrivacyURLIsHTTPSAndNotExampleDotCom() {
        let url = AppLegal.hostedPrivacyPolicyURL
        #expect(!url.absoluteString.contains("example.com"))
        #expect(url.scheme == "https")
    }

    @Test func termsUseAppleStandardEULA() {
        #expect(AppLegal.termsOfUseURL.host?.contains("apple.com") == true)
    }

    @Test func paywallPriceNeverUsesHardcodedFallback() {
        #expect(PaywallPricing.label(for: nil) == PaywallPricing.unavailableLabel)
        #expect(PaywallPricing.label(for: nil) != "$4.99")
        #expect(PaywallPricing.label(for: nil) != "$29.99")
        #expect(PaywallPricing.label(for: nil) != "$59.99")
    }
}
