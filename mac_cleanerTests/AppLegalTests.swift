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
        #expect(url.absoluteString.contains("privacy-policy"))
    }

    @Test func termsOfUseURLIsHostedHTTPS() {
        let url = AppLegal.termsOfUseURL
        #expect(url.scheme == "https")
        #expect(!url.absoluteString.contains("example.com"))
        #expect(url.absoluteString.contains("terms-of-use"))
    }

    @Test func rateUsURLUsesAppStoreID() {
        #expect(AppLegal.appStoreID == "6805994086")
        #expect(AppLegal.rateUsURL.absoluteString.contains("6805994086"))
        #expect(AppLegal.rateUsURL.absoluteString.contains("write-review"))
        #expect(AppLegal.rateUsURL.scheme == "https")
    }

    @Test func paywallPriceNeverUsesHardcodedFallback() {
        #expect(PaywallPricing.label(for: nil) == PaywallPricing.unavailableLabel)
        #expect(PaywallPricing.label(for: nil) != "$4.99")
        #expect(PaywallPricing.label(for: nil) != "$29.99")
        #expect(PaywallPricing.label(for: nil) != "$59.99")
    }
}
