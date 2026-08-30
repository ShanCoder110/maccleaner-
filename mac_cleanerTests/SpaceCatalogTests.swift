//
//  SpaceCatalogTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct SpaceCatalogTests {
    @Test func appleBackupsAndMailAreNeverDefaultSelected() {
        let risky = AppleJunkCatalog.entries.filter {
            $0.title.localizedCaseInsensitiveContains("backup")
                || $0.title.localizedCaseInsensitiveContains("mail")
        }
        #expect(!risky.isEmpty)
        #expect(risky.allSatisfy { $0.effectiveDefaultSelected == false })
        #expect(risky.allSatisfy { $0.isSensitive })
    }

    @Test func browserCachesDefaultOn() {
        let caches = AppleJunkCatalog.entries.filter { $0.title.localizedCaseInsensitiveContains("cache") }
        #expect(caches.count >= 3)
        #expect(caches.allSatisfy { $0.effectiveDefaultSelected })
    }

    @Test func developerDerivedDataAndPackageCachesDefaultOn() {
        let onByDefault = Set(
            DeveloperJunkCatalog.entries.filter(\.effectiveDefaultSelected).map(\.title)
        )
        #expect(onByDefault.contains("Xcode DerivedData"))
        #expect(onByDefault.contains("Homebrew Cache"))
        #expect(onByDefault.contains("npm Cache"))
        #expect(onByDefault.contains("pnpm Store"))
    }

    @Test func dockerArchivesAndSimulatorsNeverDefaultOn() {
        let review = DeveloperJunkCatalog.entries.filter {
            $0.title.contains("Docker")
                || $0.title.contains("Archives")
                || $0.title.contains("Simulator")
                || $0.title.contains("OrbStack")
        }
        #expect(review.count == 4)
        #expect(review.allSatisfy { $0.effectiveDefaultSelected == false })
        #expect(review.allSatisfy { $0.isSensitive })
    }

    @Test func deviceSupportIsShownButUnchecked() {
        let device = DeveloperJunkCatalog.entries.first { $0.title.contains("Device Support") }
        #expect(device?.defaultSelected == false)
        #expect(device?.isSensitive == false)
        #expect(device?.effectiveDefaultSelected == false)
    }

    @Test func sensitiveFlagOverridesDefaultSelected() {
        let entry = SpaceCatalogEntry(
            title: "Should stay off",
            relativePath: "Library/Secrets",
            category: "Test",
            isSensitive: true,
            defaultSelected: true
        )
        #expect(entry.effectiveDefaultSelected == false)
    }

    @Test func scannerSkipsPathsWithoutBookmark() {
        let items = SpaceCatalogScanner.scan(
            entries: AppleJunkCatalog.entries,
            home: "/Users/test",
            urlIfAccessible: { _ in nil },
            sizeOf: { _ in 1 },
            exists: { _ in true }
        )
        #expect(items.isEmpty)
    }

    @Test func scannerEmitsAccessibleNamedRows() {
        let backup = URL(fileURLWithPath: "/Users/test/Library/Application Support/MobileSync/Backup")
        let items = SpaceCatalogScanner.scan(
            entries: AppleJunkCatalog.entries,
            home: "/Users/test",
            urlIfAccessible: { path in
                path.hasSuffix("MobileSync/Backup") ? backup : nil
            },
            sizeOf: { _ in 40 * 1024 * 1024 * 1024 },
            exists: { _ in true },
            modified: { _ in nil }
        )

        #expect(items.count == 1)
        #expect(items[0].name == "iPhone & iPad Backups")
        #expect(items[0].isSelected == false)
        #expect(items[0].isSensitive == true)
    }

    @Test func aggregatorTreatsBackupsAsReviewNotSafe() {
        let backup = StorageItem(
            url: URL(fileURLWithPath: "/Users/me/Library/Application Support/MobileSync/Backup"),
            name: "iPhone & iPad Backups",
            category: "Apple",
            byteSize: 40 * 1024 * 1024 * 1024,
            isSelected: true,
            isSensitive: false
        )
        let derived = StorageItem(
            url: URL(fileURLWithPath: "/Users/me/Library/Developer/Xcode/DerivedData"),
            name: "Xcode DerivedData",
            category: "Xcode",
            byteSize: 12 * 1024 * 1024 * 1024,
            isSelected: true,
            isSensitive: false
        )
        let built = SmartScanAggregator.build(
            space: [
                SpaceCategory(
                    id: "apple",
                    title: "Apple Data",
                    subtitle: "test",
                    systemImage: "apple.logo",
                    items: [backup]
                ),
                SpaceCategory(
                    id: "developer",
                    title: "Developer Data",
                    subtitle: "test",
                    systemImage: "hammer",
                    items: [derived]
                )
            ],
            large: [],
            dupes: [],
            orphans: [],
            appCount: 0,
            appBytes: 0,
            coverageTitles: ["Application Support", "Xcode & Developer"],
            warnings: [],
            lastScanDate: Date(),
            resultsMayBeStale: false
        )

        #expect(built.summary.safeToRemoveSize == 12 * 1024 * 1024 * 1024)
        #expect(built.summary.reviewRecommendedSize == 40 * 1024 * 1024 * 1024)
    }

    @Test func noCatalogEntryPointsAtKeychainsOrUserData() {
        let all = SpaceCatalogGroup.allCases.flatMap(\.entries)
        #expect(all.allSatisfy { !$0.relativePath.localizedCaseInsensitiveContains("Keychain") })
        #expect(all.allSatisfy { !$0.relativePath.localizedCaseInsensitiveContains("UserData") })
        #expect(all.allSatisfy { !$0.relativePath.localizedCaseInsensitiveContains("Provisioning") })
    }
}
