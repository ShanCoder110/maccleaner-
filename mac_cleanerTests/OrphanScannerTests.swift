//
//  OrphanScannerTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct OrphanScannerTests {
    private let foo = TestFixtures.app(name: "FooBar", bundleID: "com.example.foobar")
    private let mail = TestFixtures.app(name: "Mail", bundleID: "com.tiny.x")

    @Test func leftoverNamedLikeInstalledAppIsNotOrphan() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/FooBar")
        #expect(
            AppMatcher.isOwnedByInstalledApp(url: url, apps: [foo], sensitivity: .enhanced)
        )
        let items = OrphanScanner().classify(
            candidates: [url],
            installedApps: [foo],
            sizeOf: { _ in 100_000 }
        )
        #expect(items.isEmpty)
    }

    @Test func bundleIdentifierFolderIsNotOrphan() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/com.example.foobar")
        #expect(
            AppMatcher.isOwnedByInstalledApp(url: url, apps: [foo], sensitivity: .strict)
        )
        let items = OrphanScanner(sensitivity: .strict).classify(
            candidates: [url],
            installedApps: [foo],
            sizeOf: { _ in 100_000 }
        )
        #expect(items.isEmpty)
    }

    @Test func shortNamesDoNotHideUnrelatedFolders() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/MailingList")
        #expect(
            !AppMatcher.isOwnedByInstalledApp(url: url, apps: [mail], sensitivity: .enhanced)
        )
        let items = OrphanScanner().classify(
            candidates: [url],
            installedApps: [mail],
            sizeOf: { _ in 100_000 }
        )
        #expect(items.count == 1)
        #expect(items[0].url.lastPathComponent == "MailingList")
        #expect(items[0].kind == .caches)
        #expect(items[0].isSelected == true)
    }

    @Test func unrelatedFolderRemainsOrphan() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/VanishedApp")
        let items = OrphanScanner().classify(
            candidates: [url],
            installedApps: [foo],
            sizeOf: { _ in 200_000 }
        )
        #expect(items.count == 1)
        #expect(items[0].isSelected == false)
        #expect(items[0].isSensitive == true)
    }

    @Test func possibleVendorMatchIsStillOrphan() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Application Support/example")
        #expect(
            !AppMatcher.isOwnedByInstalledApp(url: url, apps: [foo], sensitivity: .deep)
        )
        let items = OrphanScanner(sensitivity: .deep).classify(
            candidates: [url],
            installedApps: [foo],
            sizeOf: { _ in 100_000 }
        )
        #expect(items.count == 1)
    }

    @Test func tinyItemsAreIgnored() {
        let url = URL(fileURLWithPath: "/Users/me/Library/Caches/OldTool")
        let items = OrphanScanner().classify(
            candidates: [url],
            installedApps: [],
            sizeOf: { _ in 1024 }
        )
        #expect(items.isEmpty)
    }
}
