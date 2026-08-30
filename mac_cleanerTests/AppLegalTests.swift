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

    @Test func hostedPrivacyURLIsNeverExampleDotCom() {
        if let url = AppLegal.hostedPrivacyPolicyURL {
            #expect(!url.absoluteString.contains("example.com"))
            #expect(url.scheme == "https")
        }
    }

    @Test func termsUseAppleStandardEULA() {
        #expect(AppLegal.termsOfUseURL.host?.contains("apple.com") == true)
    }

    @Test func privacyPolicyDescribesOnDeviceAndTrashOnly() {
        let text = AppLegal.privacyPolicyText.lowercased()
        #expect(text.contains("telemetry") || text.contains("analytics"))
        #expect(text.contains("trash"))
        #expect(text.contains("bookmark") || text.contains("folder"))
        #expect(text.contains("storekit") || text.contains("apple"))
        #expect(!text.contains("example.com"))
    }

    @Test func paywallPriceNeverUsesHardcodedFallback() {
        #expect(PaywallPricing.label(for: nil) == PaywallPricing.unavailableLabel)
        #expect(PaywallPricing.label(for: nil) != "$4.99")
        #expect(PaywallPricing.label(for: nil) != "$29.99")
        #expect(PaywallPricing.label(for: nil) != "$59.99")
    }
}
