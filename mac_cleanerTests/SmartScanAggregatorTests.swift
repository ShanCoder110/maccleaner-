//
//  SmartScanAggregatorTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct SmartScanAggregatorTests {
    @Test func applicationBytesAreNotCountedAsRecoverable() {
        let cache = StorageItem(
            url: URL(fileURLWithPath: "/Users/me/Library/Caches/com.example.foo"),
            name: "com.example.foo",
            category: "Authorized Caches",
            byteSize: 200 * 1024 * 1024,
            isSelected: true,
            isSensitive: false
        )
        let space = [
            SpaceCategory(
                id: "caches",
                title: "Authorized Caches",
                subtitle: "test",
                systemImage: "externaldrive",
                items: [cache]
            )
        ]

        let built = SmartScanAggregator.build(
            space: space,
            large: [],
            dupes: [],
            orphans: [],
            appCount: 12,
            appBytes: 8 * 1024 * 1024 * 1024,
            coverageTitles: ["Caches"],
            warnings: [],
            lastScanDate: Date(),
            resultsMayBeStale: false
        )

        #expect(built.summary.safeToRemoveSize == 200 * 1024 * 1024)
        #expect(built.summary.totalDiscoveredSize == 200 * 1024 * 1024)
        #expect(built.summary.safeToRemoveSize < 8 * 1024 * 1024 * 1024)

        let apps = built.summaries.first { $0.id == "apps" }
        #expect(apps?.recoverableBytes == 0)
        #expect(apps?.totalBytes == 8 * 1024 * 1024 * 1024)
        #expect(apps?.safety == .informational)
    }

    @Test func applicationSupportIsReviewNotSafe() {
        let support = StorageItem(
            url: URL(fileURLWithPath: "/Users/me/Library/Application Support/HugeApp"),
            name: "HugeApp",
            category: "Application Support (large)",
            byteSize: 80 * 1024 * 1024,
            isSelected: true,
            isSensitive: false
        )
        let built = SmartScanAggregator.build(
            space: [
                SpaceCategory(
                    id: "support",
                    title: "Application Support (large)",
                    subtitle: "test",
                    systemImage: "folder",
                    items: [support]
                )
            ],
            large: [],
            dupes: [],
            orphans: [],
            appCount: 0,
            appBytes: 0,
            coverageTitles: ["Application Support"],
            warnings: [],
            lastScanDate: Date(),
            resultsMayBeStale: false
        )

        #expect(built.summary.safeToRemoveSize == 0)
        #expect(built.summary.reviewRecommendedSize == 80 * 1024 * 1024)
    }
}
