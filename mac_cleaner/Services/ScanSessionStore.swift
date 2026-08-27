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

    @Published var categorySummaries: [SmartScanCategoryResult] = []
    @Published var spaceCategories: [SpaceCategory] = []
    @Published var largeFiles: [StorageItem] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var orphanItems: [LeftoverItem] = []
    @Published var applicationCount = 0
    @Published var applicationsBytes: Int64 = 0

    var hasResults: Bool {
        lastScanDate != nil
    }

    /// Junk = selected Space Cleaner items (safe defaults already selected).
    var junkBytes: Int64 {
        spaceCategories
            .flatMap(\.items)
            .filter(\.isSelected)
            .reduce(0) { $0 + $1.byteSize }
    }

    var junkItemCount: Int {
        spaceCategories.flatMap(\.items).filter(\.isSelected).count
    }

    var junkURLs: [URL] {
        spaceCategories.flatMap(\.items).filter(\.isSelected).map(\.url)
    }

    var totalFoundBytes: Int64 {
        categorySummaries.reduce(0) { $0 + $1.totalBytes }
    }

    func updateProgress(_ value: Double, label: String) {
        let clamped = min(max(value, 0), 1)
        progress = clamped
        progressPercent = Int((clamped * 100).rounded())
        progressLabel = label
    }

    func apply(
        summaries: [SmartScanCategoryResult],
        space: [SpaceCategory],
        large: [StorageItem],
        dupes: [DuplicateGroup],
        orphans: [LeftoverItem],
        appCount: Int,
        appBytes: Int64
    ) {
        categorySummaries = summaries
        spaceCategories = space
        largeFiles = large
        duplicateGroups = dupes
        orphanItems = orphans
        applicationCount = appCount
        applicationsBytes = appBytes
        lastScanDate = Date()
        isScanning = false
        updateProgress(1, label: "Scan complete")
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

        rebuildSummaries()
    }

    func rebuildSummaries() {
        let spaceBytes = spaceCategories.reduce(Int64(0)) { $0 + $1.totalBytes }
        let spaceCount = spaceCategories.reduce(0) { $0 + $1.items.count }
        let largeBytes = largeFiles.reduce(Int64(0)) { $0 + $1.byteSize }
        let dupeBytes = duplicateGroups.reduce(Int64(0)) { partial, group in
            partial + (group.byteSize * Int64(max(0, group.files.count - 1)))
        }
        let orphanBytes = orphanItems.reduce(Int64(0)) { $0 + $1.byteSize }

        categorySummaries = [
            SmartScanCategoryResult(
                id: "space",
                title: "Space Cleaner",
                systemImage: "internaldrive",
                totalBytes: spaceBytes,
                itemCount: spaceCount,
                progress: spaceBytes == 0 ? 0.05 : min(1, Double(spaceBytes) / Double(max(spaceBytes, 1))),
                destination: .spaceCleaner
            ),
            SmartScanCategoryResult(
                id: "large",
                title: "Large Files",
                systemImage: "doc.on.doc",
                totalBytes: largeBytes,
                itemCount: largeFiles.count,
                progress: largeFiles.isEmpty ? 0.05 : 0.7,
                destination: .largeFiles
            ),
            SmartScanCategoryResult(
                id: "dupes",
                title: "Duplicates",
                systemImage: "rectangle.on.rectangle",
                totalBytes: dupeBytes,
                itemCount: duplicateGroups.count,
                progress: duplicateGroups.isEmpty ? 0.05 : 0.55,
                destination: .duplicates
            ),
            SmartScanCategoryResult(
                id: "orphans",
                title: "Orphans",
                systemImage: "tray",
                totalBytes: orphanBytes,
                itemCount: orphanItems.count,
                progress: orphanItems.isEmpty ? 0.05 : 0.5,
                destination: .orphans
            ),
            SmartScanCategoryResult(
                id: "apps",
                title: "Applications",
                systemImage: "square.grid.2x2",
                totalBytes: applicationsBytes,
                itemCount: applicationCount,
                progress: 0.4,
                destination: .applications
            ),
        ]
    }
}

enum SmartScanRunner {
    static func run(
        bookmarks: BookmarkStore,
        session: ScanSessionStore,
        onProgress: @escaping @MainActor (Double, String) -> Void
    ) async {
        await MainActor.run {
            session.isScanning = true
            session.updateProgress(0.02, label: "Starting scan…")
        }

        let roots = await MainActor.run { bookmarks.accessibleRootURLs }

        await MainActor.run { onProgress(0.08, "Scanning caches & logs…") }

        let space = await Task.detached(priority: .userInitiated) {
            SpaceCleanerScanner(bookmarks: bookmarks).scan()
        }.value

        await MainActor.run { onProgress(0.24, "Finding large files…") }

        let large = await Task.detached(priority: .userInitiated) {
            LargeFilesScanner(minimumBytes: 50 * 1024 * 1024).scan(roots: roots)
        }.value

        await MainActor.run { onProgress(0.42, "Comparing duplicates…") }

        let dupes = await Task.detached(priority: .userInitiated) {
            DuplicateFinder().findDuplicates(roots: roots)
        }.value

        await MainActor.run { onProgress(0.60, "Listing applications…") }

        let apps = await Task.detached(priority: .userInitiated) {
            AppInventoryService().loadInstalledApps().filter { !$0.isSystemApp }
        }.value

        await MainActor.run { onProgress(0.74, "Looking for orphans…") }

        let orphans = await Task.detached(priority: .userInitiated) {
            OrphanScanner(bookmarks: bookmarks).scan(installedApps: apps)
        }.value

        await MainActor.run { onProgress(0.88, "Checking AI tool data…") }

        let ai = await Task.detached(priority: .userInitiated) {
            AIJunkCatalog.scan(bookmarks: bookmarks)
        }.value

        var mergedSpace = space
        if !ai.isEmpty {
            if let idx = mergedSpace.firstIndex(where: { $0.id == "ai" }) {
                mergedSpace[idx].items = ai
            } else {
                mergedSpace.append(
                    SpaceCategory(
                        id: "ai",
                        title: "AI Tool Data",
                        subtitle: "Claude, Codex, Cursor, and related caches",
                        systemImage: "brain",
                        items: ai,
                        isExpanded: true
                    )
                )
            }
        }

        for i in mergedSpace.indices {
            mergedSpace[i].isExpanded = mergedSpace[i].id == "ai" || mergedSpace.count <= 3
        }

        let spaceBytes = mergedSpace.reduce(Int64(0)) { $0 + $1.totalBytes }
        let spaceCount = mergedSpace.reduce(0) { $0 + $1.items.count }
        let largeBytes = large.reduce(Int64(0)) { $0 + $1.byteSize }
        let dupeBytes = dupes.reduce(Int64(0)) { $0 + ($1.byteSize * Int64(max(0, $1.files.count - 1))) }
        let orphanBytes = orphans.reduce(Int64(0)) { $0 + $1.byteSize }
        let appBytes = apps.prefix(20).reduce(Int64(0)) { $0 + $1.byteSize }

        let summaries = [
            SmartScanCategoryResult(
                id: "space",
                title: "Space Cleaner",
                systemImage: "internaldrive",
                totalBytes: spaceBytes,
                itemCount: spaceCount,
                progress: spaceBytes == 0 ? 0.05 : 0.85,
                destination: .spaceCleaner
            ),
            SmartScanCategoryResult(
                id: "large",
                title: "Large Files",
                systemImage: "doc.on.doc",
                totalBytes: largeBytes,
                itemCount: large.count,
                progress: large.isEmpty ? 0.05 : 0.7,
                destination: .largeFiles
            ),
            SmartScanCategoryResult(
                id: "dupes",
                title: "Duplicates",
                systemImage: "rectangle.on.rectangle",
                totalBytes: dupeBytes,
                itemCount: dupes.count,
                progress: dupes.isEmpty ? 0.05 : 0.55,
                destination: .duplicates
            ),
            SmartScanCategoryResult(
                id: "orphans",
                title: "Orphans",
                systemImage: "tray",
                totalBytes: orphanBytes,
                itemCount: orphans.count,
                progress: orphans.isEmpty ? 0.05 : 0.5,
                destination: .orphans
            ),
            SmartScanCategoryResult(
                id: "apps",
                title: "Applications",
                systemImage: "square.grid.2x2",
                totalBytes: appBytes,
                itemCount: apps.count,
                progress: 0.4,
                destination: .applications
            ),
        ]

        await MainActor.run {
            onProgress(1.0, "Scan complete")
            session.apply(
                summaries: summaries,
                space: mergedSpace,
                large: large,
                dupes: dupes,
                orphans: orphans,
                appCount: apps.count,
                appBytes: appBytes
            )
        }
    }
}
