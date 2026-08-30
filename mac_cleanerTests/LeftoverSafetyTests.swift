//
//  LeftoverSafetyTests.swift
//  mac_cleanerTests
//
//  Possible / sensitive / shared items must never auto-select.
//

import Foundation
import Testing
@testable import mac_cleaner

struct LeftoverSafetyTests {
    @Test func possibleConfidenceNeverAutoSelected() {
        let selected = LeftoverItem.defaultSelection(
            kind: .caches,
            confidence: .possible,
            safety: .safeToRemove,
            isShared: false
        )
        #expect(selected == false)
    }

    @Test func sensitiveNeverAutoSelected() {
        let selected = LeftoverItem.defaultSelection(
            kind: .other,
            confidence: .confirmed,
            safety: .sensitive,
            isShared: false
        )
        #expect(selected == false)
    }

    @Test func sharedNeverAutoSelected() {
        let selected = LeftoverItem.defaultSelection(
            kind: .caches,
            confidence: .confirmed,
            safety: .safeToRemove,
            isShared: true
        )
        #expect(selected == false)
    }

    @Test func confirmedCacheIsAutoSelected() {
        let selected = LeftoverItem.defaultSelection(
            kind: .caches,
            confidence: .confirmed,
            safety: .safeToRemove,
            isShared: false
        )
        #expect(selected == true)
    }

    @Test func applicationSupportIsReviewNotAutoSelected() {
        let selected = LeftoverItem.defaultSelection(
            kind: .applicationSupport,
            confidence: .likely,
            safety: .reviewRecommended,
            isShared: false
        )
        #expect(selected == false)
    }

    @Test func leftoverInitForcesSensitiveUnchecked() {
        let item = LeftoverItem(
            url: URL(fileURLWithPath: "/Users/me/.codex/auth.json"),
            kind: .other,
            byteSize: 100,
            isSelected: true,
            isSensitive: true,
            matchConfidence: .confirmed,
            matchReason: .bundleIdentifier
        )
        #expect(item.isSelected == false)
        #expect(item.safety == .sensitive)
    }

    @Test(arguments: [
        "/Users/me/.ssh/id_rsa",
        "/Users/me/.aws/credentials",
        "/tmp/secret.pem",
        "/tmp/server.key",
        "/Users/me/Library/Keychains/login.keychain-db",
        "/Users/me/.codex/auth.json",
        "/Users/me/.codex/config.toml"
    ])
    func sensitivePathsAreDetected(path: String) {
        #expect(PathNormalization.isSensitivePath(URL(fileURLWithPath: path)))
    }

    @Test func ordinaryCacheIsNotSensitive() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/com.example.foobar")
        #expect(PathNormalization.isSensitivePath(url) == false)
        #expect(SafetyClassification.classify(kind: .caches, url: url) == .safeToRemove)
    }
}
