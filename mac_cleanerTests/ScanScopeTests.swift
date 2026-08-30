//
//  ScanScopeTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct ScanScopeTests {
    private func scope(
        home: String = "/Users/test",
        roots: [String],
        kinds: [GrantedFolder.Kind] = []
    ) -> ScanScope {
        let urls = roots.map { URL(fileURLWithPath: $0) }
        let folders: [ScanFolderSnapshot]
        if kinds.isEmpty {
            folders = []
        } else {
            folders = zip(kinds, urls).map { ScanFolderSnapshot(kind: $0, url: $1) }
        }
        return ScanScope(
            home: home,
            roots: urls,
            coverageTitles: kinds.map(\.title),
            folders: folders
        )
    }

    @Test func urlIfAccessibleRequiresCoveringRoot() {
        let scan = scope(roots: ["/Users/test/Library/Caches"])

        #expect(scan.urlIfAccessible("/Users/test/Library/Caches") != nil)
        #expect(scan.urlIfAccessible("/Users/test/Library/Caches/Safari") != nil)
        #expect(scan.urlIfAccessible("/Users/test/Library/Application Support/MobileSync/Backup") == nil)
        #expect(scan.urlIfAccessible("/tmp/outside") == nil)
    }

    @Test func urlIfAccessibleDoesNotTreatPrefixSiblingsAsCovered() {
        let scan = scope(roots: ["/Users/test"])

        #expect(scan.urlIfAccessible("/Users/test/Library/Caches") != nil)
        #expect(scan.urlIfAccessible("/Users/testing/Library/Caches") == nil)
        #expect(scan.urlIfAccessible("/Users/test-extra") == nil)
    }

    @Test func rootsForKindUsesFolderSnapshots() {
        let caches = URL(fileURLWithPath: "/Users/test/Library/Caches")
        let logs = URL(fileURLWithPath: "/Users/test/Library/Logs")
        let scan = ScanScope(
            home: "/Users/test",
            roots: [caches, logs],
            coverageTitles: ["Caches", "Logs"],
            folders: [
                ScanFolderSnapshot(kind: .caches, url: caches),
                ScanFolderSnapshot(kind: .logs, url: logs)
            ]
        )

        #expect(scan.roots(for: .caches) == [caches])
        #expect(scan.roots(for: .developer).isEmpty)
        #expect(scan.rootsMatchingPathComponent("Caches") == [caches])
    }

    @Test func catalogScannerSkipsPathsOutsideScope() {
        let scan = scope(roots: ["/Users/test/Documents"])
        let items = SpaceCatalogScanner.scan(
            entries: AppleJunkCatalog.entries,
            home: "/Users/test",
            urlIfAccessible: { scan.urlIfAccessible($0) },
            sizeOf: { _ in 1 },
            exists: { _ in true }
        )
        #expect(items.isEmpty)
    }

    @Test func catalogScannerIncludesAccessibleNamedRows() {
        let support = URL(fileURLWithPath: "/Users/test/Library/Application Support")
        let scan = ScanScope(
            home: "/Users/test",
            roots: [support],
            coverageTitles: ["Application Support"],
            folders: [ScanFolderSnapshot(kind: .applicationSupport, url: support)]
        )
        let items = SpaceCatalogScanner.scan(
            entries: AppleJunkCatalog.entries,
            home: "/Users/test",
            urlIfAccessible: { scan.urlIfAccessible($0) },
            sizeOf: { _ in 40 * 1024 * 1024 * 1024 },
            exists: { _ in true }
        )

        #expect(items.count == 1)
        #expect(items[0].name == "iPhone & iPad Backups")
        #expect(items[0].isSelected == false)
        #expect(items[0].isSensitive == true)
    }

    @Test @MainActor func markCancelledKeepsPreviousResults() {
        let session = ScanSessionStore()
        let results = ScanResultsHub()
        let item = StorageItem(
            url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example"),
            category: "Caches",
            byteSize: 1_000_000,
            isSelected: true
        )
        results.replace(
            space: [
                SpaceCategory(
                    id: "caches",
                    title: "Authorized Caches",
                    subtitle: "test",
                    systemImage: "externaldrive",
                    items: [item]
                )
            ],
            large: [],
            dupes: [],
            orphans: []
        )
        session.applyMetadata(
            appCount: 3,
            appBytes: 90,
            coverageTitles: ["Caches"],
            warnings: []
        )
        session.rebuildSummaries(from: results)
        let previousDate = session.lastScanDate
        #expect(previousDate != nil)

        session.isScanning = true
        session.resetStages()
        session.setStage(.cachesLogs, status: .running)
        session.markCancelled()

        #expect(session.isScanning == false)
        #expect(session.lastScanDate == previousDate)
        #expect(session.applicationCount == 3)
        #expect(results.space.categories.count == 1)
        #expect(session.scanStages.contains { $0.status == .skipped && $0.detail == "Cancelled" })
        #expect(session.progressLabel.contains("previous results kept"))
    }

    @Test @MainActor func cleaningDuplicatesUpdatesSmartScanSummary() {
        let session = ScanSessionStore()
        let results = ScanResultsHub()
        let keep = DuplicateFile(
            url: URL(fileURLWithPath: "/Users/test/Documents/photo.jpg"),
            byteSize: 2_000_000,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified,
            isSelected: false,
            isRecommendedKeep: true
        )
        let dupe = DuplicateFile(
            url: URL(fileURLWithPath: "/Users/test/Downloads/photo copy.jpg"),
            byteSize: 2_000_000,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified,
            isSelected: true
        )
        results.replace(
            space: [],
            large: [],
            dupes: [
                DuplicateGroup(
                    byteSize: 2_000_000,
                    files: [keep, dupe],
                    confidence: .confirmed,
                    keepRecommendation: .recommended,
                    keepID: keep.id
                )
            ],
            orphans: []
        )
        session.applyMetadata(appCount: 0, appBytes: 0, coverageTitles: ["Downloads"], warnings: [])
        session.rebuildSummaries(from: results)
        #expect(session.summary.recoverableSize == 2_000_000)

        results.clearAfterClean(removedURLs: [dupe.url])
        session.resultsMayBeStale = true
        session.rebuildSummaries(from: results)

        #expect(results.duplicates.groups.isEmpty)
        #expect(session.summary.recoverableSize == 0)
        #expect(session.resultsMayBeStale)
    }
}
