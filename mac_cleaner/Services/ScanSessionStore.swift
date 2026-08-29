//
//  ScanSessionStore.swift
//  mac_cleaner
//
//  Shared scan results so Smart Scan and category pages stay in sync.
//

import Foundation
import Combine

final class ScanSessionStore: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var progressPercent: Int = 0
    @Published var progressLabel = "Ready to scan"
    @Published var lastScanDate: Date?
    @Published var resultsMayBeStale = false

    @Published var categorySummaries: [SmartScanCategoryResult] = []
    @Published var summary: SmartScanSummary = .empty
    @Published var scanStages: [SmartScanStage] = SmartScanStageID.allCases.map {
        SmartScanStage(id: $0, status: .pending, detail: nil)
    }

    @Published var spaceCategories: [SpaceCategory] = []
    @Published var largeFiles: [StorageItem] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var orphanItems: [LeftoverItem] = []
    @Published var applicationCount = 0
    @Published var applicationsBytes: Int64 = 0
    @Published var coverageTitles: [String] = []
    @Published var scannerWarnings: [String] = []

    var hasResults: Bool {
        lastScanDate != nil
    }

    /// Junk = selected, non-sensitive Space Cleaner items (safe defaults).
    var junkBytes: Int64 {
        spaceCategories
            .flatMap(\.items)
            .filter { $0.isSelected && !$0.isSensitive }
            .reduce(0) { $0 + $1.byteSize }
    }

    var junkItemCount: Int {
        spaceCategories.flatMap(\.items).filter { $0.isSelected && !$0.isSensitive }.count
    }

    var junkURLs: [URL] {
        spaceCategories.flatMap(\.items).filter { $0.isSelected && !$0.isSensitive }.map(\.url)
    }

    var totalFoundBytes: Int64 {
        summary.totalDiscoveredSize
    }

    func updateProgress(_ value: Double, label: String) {
        let clamped = min(max(value, 0), 1)
        progress = clamped
        progressPercent = Int((clamped * 100).rounded())
        progressLabel = label
    }

    func resetStages() {
        scanStages = SmartScanStageID.allCases.map {
            SmartScanStage(id: $0, status: .pending, detail: nil)
        }
    }

    func setStage(_ id: SmartScanStageID, status: SmartScanStageStatus, detail: String? = nil) {
        guard let index = scanStages.firstIndex(where: { $0.id == id }) else { return }
        scanStages[index].status = status
        scanStages[index].detail = detail
    }

    func apply(
        space: [SpaceCategory],
        large: [StorageItem],
        dupes: [DuplicateGroup],
        orphans: [LeftoverItem],
        appCount: Int,
        appBytes: Int64,
        coverageTitles: [String],
        warnings: [String]
    ) {
        spaceCategories = space
        largeFiles = large
        duplicateGroups = dupes
        orphanItems = orphans
        applicationCount = appCount
        applicationsBytes = appBytes
        self.coverageTitles = coverageTitles
        scannerWarnings = warnings
        lastScanDate = Date()
        resultsMayBeStale = false
        isScanning = false
        updateProgress(1, label: "Scan complete")
        rebuildSummaries()
    }

    func markStale() {
        guard hasResults else { return }
        resultsMayBeStale = true
        rebuildSummaries()
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        for i in spaceCategories.indices {
            spaceCategories[i].items.removeAll { removedURLs.contains($0.url) }
        }
        spaceCategories.removeAll { $0.items.isEmpty }

        largeFiles.removeAll { removedURLs.contains($0.url) }

        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { removedURLs.contains($0.url) }
        }
        duplicateGroups.removeAll { $0.files.count < 2 }

        orphanItems.removeAll { removedURLs.contains($0.url) }

        resultsMayBeStale = true
        rebuildSummaries()
    }

    func rebuildSummaries() {
        let built = SmartScanAggregator.build(
            space: spaceCategories,
            large: largeFiles,
            dupes: duplicateGroups,
            orphans: orphanItems,
            appCount: applicationCount,
            appBytes: applicationsBytes,
            coverageTitles: coverageTitles,
            warnings: scannerWarnings,
            lastScanDate: lastScanDate,
            resultsMayBeStale: resultsMayBeStale
        )
        categorySummaries = built.summaries
        summary = built.summary
    }
}

enum SmartScanRunner {
    static func run(
        bookmarks: BookmarkStore,
        session: ScanSessionStore,
        onProgress: @escaping @MainActor (Double, String) -> Void
    ) async {
        let coverage = await MainActor.run { bookmarks.folders.map(\.kind.title).sorted() }
        let roots = await MainActor.run { bookmarks.accessibleRootURLs }

        await MainActor.run {
            session.isScanning = true
            session.resultsMayBeStale = false
            session.scannerWarnings = []
            session.coverageTitles = coverage
            session.resetStages()
            session.updateProgress(0.02, label: "Starting scan…")
            onProgress(0.02, "Starting scan…")
        }

        var warnings: [String] = []
        var space: [SpaceCategory] = []
        var large: [StorageItem] = []
        var dupes: [DuplicateGroup] = []
        var orphans: [LeftoverItem] = []
        var apps: [InstalledApp] = []

        // 1. Caches & logs
        await MainActor.run {
            session.setStage(.cachesLogs, status: .running)
            onProgress(0.08, "Scanning caches & logs…")
            session.updateProgress(0.08, label: "Scanning caches & logs…")
        }
        space = await Task.detached(priority: .userInitiated) {
            SpaceCleanerScanner(bookmarks: bookmarks).scan()
        }.value
        await MainActor.run {
            let bytes = space.reduce(Int64(0)) { $0 + $1.totalBytes }
            session.setStage(.cachesLogs, status: .completed, detail: ByteFormat.string(from: bytes))
        }

        // 2. Large files
        await MainActor.run {
            session.setStage(.largeFiles, status: .running)
            onProgress(0.24, "Finding large files…")
            session.updateProgress(0.24, label: "Finding large files…")
        }
        if roots.isEmpty {
            await MainActor.run { session.setStage(.largeFiles, status: .skipped, detail: "No folders") }
            warnings.append("Large files limited — authorize folders to scan")
        } else {
            large = await Task.detached(priority: .userInitiated) {
                LargeFilesScanner(minimumBytes: 50 * 1024 * 1024).scan(roots: roots)
            }.value
            await MainActor.run {
                let bytes = large.reduce(Int64(0)) { $0 + $1.byteSize }
                session.setStage(.largeFiles, status: .completed, detail: ByteFormat.string(from: bytes))
            }
        }

        // 3. Duplicates
        await MainActor.run {
            session.setStage(.duplicates, status: .running)
            onProgress(0.42, "Comparing duplicates…")
            session.updateProgress(0.42, label: "Comparing duplicates…")
        }
        if roots.isEmpty {
            await MainActor.run { session.setStage(.duplicates, status: .skipped, detail: "No folders") }
        } else {
            dupes = await Task.detached(priority: .userInitiated) {
                DuplicateFinder().findDuplicates(roots: roots)
            }.value
            await MainActor.run {
                let bytes = dupes.reduce(Int64(0)) { $0 + $1.recoverableBytes }
                session.setStage(.duplicates, status: .completed, detail: ByteFormat.string(from: bytes))
            }
        }

        // 4. Applications
        await MainActor.run {
            session.setStage(.applications, status: .running)
            onProgress(0.60, "Listing applications…")
            session.updateProgress(0.60, label: "Listing applications…")
        }
        apps = await Task.detached(priority: .userInitiated) {
            AppInventoryService().loadInstalledApps().filter { !$0.isSystemApp }
        }.value
        await MainActor.run {
            session.setStage(.applications, status: .completed, detail: "\(apps.count) apps")
        }

        // 5. Orphans
        await MainActor.run {
            session.setStage(.orphans, status: .running)
            onProgress(0.74, "Looking for leftovers…")
            session.updateProgress(0.74, label: "Looking for leftovers…")
        }
        if roots.isEmpty {
            await MainActor.run { session.setStage(.orphans, status: .skipped, detail: "No folders") }
        } else {
            let installed = apps
            orphans = await Task.detached(priority: .userInitiated) {
                OrphanScanner(bookmarks: bookmarks).scan(installedApps: installed)
            }.value
            await MainActor.run {
                let bytes = orphans.reduce(Int64(0)) { $0 + $1.byteSize }
                session.setStage(.orphans, status: .completed, detail: ByteFormat.string(from: bytes))
            }
        }

        // 6. AI tool data (already included by SpaceCleanerScanner — report stage only)
        await MainActor.run {
            session.setStage(.aiData, status: .running)
            onProgress(0.88, "Checking AI tool data…")
            session.updateProgress(0.88, label: "Checking AI tool data…")
        }
        let aiCategory = space.first(where: { $0.id == "ai" })
        let aiBytes = aiCategory?.totalBytes ?? 0
        let aiFound = !(aiCategory?.items.isEmpty ?? true)
        await MainActor.run {
            session.setStage(
                .aiData,
                status: aiFound ? .completed : .skipped,
                detail: aiFound ? ByteFormat.string(from: aiBytes) : "None found"
            )
        }

        var mergedSpace = space
        for i in mergedSpace.indices {
            mergedSpace[i].isExpanded = mergedSpace[i].id == "ai" || mergedSpace.count <= 3
        }

        // App bytes are inventory only — full list size estimate, not “recoverable”.
        let appBytes = apps.reduce(Int64(0)) { $0 + $1.byteSize }

        await MainActor.run {
            onProgress(1.0, "Scan complete")
            session.apply(
                space: mergedSpace,
                large: large,
                dupes: dupes,
                orphans: orphans,
                appCount: apps.count,
                appBytes: appBytes,
                coverageTitles: coverage,
                warnings: warnings
            )
        }
    }
}
