//
//  AppMatcherTests.swift
//  mac_cleanerTests
//
//  Frozen leftover-matching contract. Selection defaults depend on these hits.
//

import Foundation
import Testing
@testable import mac_cleaner

@MainActor
struct AppMatcherTests {
    private let foo = TestFixtures.app(name: "FooBar", bundleID: "com.example.foobar")

    @Test func bundleIdentifierMatchIsConfirmed() {
        let matcher = AppMatcher(app: foo, sensitivity: .strict)
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/com.example.foobar")
        let hit = matcher.matches(name: "com.example.foobar", url: url)

        #expect(hit?.confidence == .confirmed)
        #expect(hit?.reason == .bundleIdentifier)
    }

    @Test func bundleIdentifierInPathIsConfirmed() {
        let matcher = AppMatcher(app: foo, sensitivity: .strict)
        let url = URL(fileURLWithPath: "/Users/me/Library/Containers/com.example.foobar/Data")
        let hit = matcher.matches(name: "Data", url: url)

        #expect(hit?.confidence == .confirmed)
        #expect(hit?.reason == .bundleIdentifier)
    }

    @Test func exactAppNameIsLikely() {
        let matcher = AppMatcher(app: foo, sensitivity: .enhanced)
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/FooBar")
        let hit = matcher.matches(name: "FooBar", url: url)

        #expect(hit?.confidence == .likely)
        #expect(hit?.reason == .exactAppName)
    }

    @Test func strictSensitivityIgnoresNameContains() {
        let matcher = AppMatcher(app: foo, sensitivity: .strict)
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/FooBarCache")
        let hit = matcher.matches(name: "FooBarCache", url: url)

        #expect(hit == nil)
    }

    @Test func enhancedSensitivityMatchesNormalizedNameContains() {
        let matcher = AppMatcher(app: foo, sensitivity: .enhanced)
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/FooBarCache")
        let hit = matcher.matches(name: "FooBarCache", url: url)

        #expect(hit?.confidence == .likely)
        #expect(hit?.reason == .normalizedName)
    }

    @Test func vendorNameIsPossibleOnlyInDeep() {
        let matcherEnhanced = AppMatcher(app: foo, sensitivity: .enhanced)
        let matcherDeep = AppMatcher(app: foo, sensitivity: .deep)
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/example")

        #expect(matcherEnhanced.matches(name: "example", url: url) == nil)
        #expect(matcherDeep.matches(name: "example", url: url)?.confidence == .possible)
        #expect(matcherDeep.matches(name: "example", url: url)?.reason == .vendorName)
    }

    @Test func shortNamesDoNotMatchByName() {
        let short = TestFixtures.app(name: "Mail", bundleID: "com.tiny.x")
        let matcher = AppMatcher(app: short, sensitivity: .enhanced)
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/MailingList")

        #expect(matcher.matches(name: "MailingList", url: url) == nil)
    }
}
