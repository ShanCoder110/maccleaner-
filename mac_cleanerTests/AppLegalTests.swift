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

    @Test func autoRenewLegalTextIncludesPriceLengthAndAppleSentences() {
        let text = PaywallPricing.autoRenewLegalText(displayPrice: "$4.99", period: .month)
        #expect(text.contains("Pro Monthly"))
        #expect(text.contains("1 month"))
        #expect(text.contains("$4.99 per month"))
        #expect(text.contains("3-day free trial"))
        #expect(text.contains("eligible new subscribers"))
        #expect(text.contains("Payment will be charged to your Apple ID account at confirmation of purchase"))
        #expect(text.contains("automatically renews"))
        #expect(text.contains("24 hours"))
        #expect(text.contains("within 24 hours prior to the end of the current period"))
        #expect(text.contains("Account Settings"))
        #expect(!text.contains("$29.99"))
    }

    @Test func autoRenewLegalTextDoesNotInventAPriceWhenUnavailable() {
        let text = PaywallPricing.autoRenewLegalText(
            displayPrice: PaywallPricing.unavailableLabel,
            period: .year
        )
        #expect(text.contains("Pro Yearly"))
        #expect(text.contains("1 year"))
        #expect(text.contains("the price shown above per year"))
        #expect(!text.contains("$"))
    }

    @Test func lifetimeLegalTextIsNotAutoRenewing() {
        let text = PaywallPricing.lifetimeLegalText(displayPrice: "$59.99")
        #expect(text.contains("$59.99"))
        #expect(text.contains("one-time"))
        #expect(text.contains("does not auto-renew"))
        #expect(!text.contains("automatically renews"))
        #expect(!text.contains("free trial"))
    }
}
