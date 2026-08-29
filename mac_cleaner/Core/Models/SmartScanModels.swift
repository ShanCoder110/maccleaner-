//
//  SmartScanModels.swift
//  mac_cleaner
//
//  Decision-oriented Smart Scan summaries built on shared ScanSessionStore data.
//

import Foundation

enum SmartScanCategorySafety: String, Hashable {
    case safe
    case review
    case mixed
    case informational

    var title: String {
        switch self {
        case .safe: return "Safe to remove"
        case .review: return "Review recommended"
        case .mixed: return "Mixed — review recommended"
        case .informational: return "Review apps"
        }
    }

    var shortTitle: String {
        switch self {
        case .safe: return "Safe"
        case .review: return "Review"
        case .mixed: return "Mixed"
        case .informational: return "Review"
        }
    }

    var badgeStyle: StatusBadgeStyle {
        switch self {
        case .safe: return .success
        case .review, .mixed: return .warning
        case .informational: return .info
        }
    }
}

enum SmartScanStageID: String, CaseIterable, Identifiable, Hashable {
    case cachesLogs
    case largeFiles
    case duplicates
    case applications
    case orphans
    case aiData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cachesLogs: return "Caches & logs"
        case .largeFiles: return "Large files"
        case .duplicates: return "Duplicates"
        case .applications: return "Applications"
        case .orphans: return "Orphans"
        case .aiData: return "AI tool data"
        }
    }
}

enum SmartScanStageStatus: String, Hashable {
    case pending
    case running
    case completed
    case failed
    case skipped
}

struct SmartScanStage: Identifiable, Hashable {
    var id: SmartScanStageID
    var status: SmartScanStageStatus
    var detail: String?

    var title: String { id.title }
}

struct SmartScanOpportunity: Identifiable, Hashable {
    let id: String
    let title: String
    let bytes: Int64
    let safety: SmartScanCategorySafety
    let destination: AppDestination?

    var sizeLabel: String { ByteFormat.string(from: bytes) }
}

struct SmartScanSummary: Hashable {
    var totalDiscoveredSize: Int64
    var safeToRemoveSize: Int64
    var reviewRecommendedSize: Int64
    var totalItemCount: Int
    var safeItemCount: Int
    var reviewItemCount: Int
    var lastScanDate: Date?
    var coverageTitles: [String]
    var topOpportunities: [SmartScanOpportunity]
    var resultsMayBeStale: Bool
    var scannerWarnings: [String]
    var folderAccessLimited: Bool

    var recoverableSize: Int64 { safeToRemoveSize + reviewRecommendedSize }

    var hasMeaningfulRecovery: Bool {
        recoverableSize >= 1 * 1024 * 1024 // ≥ 1 MB
    }

    static let empty = SmartScanSummary(
        totalDiscoveredSize: 0,
        safeToRemoveSize: 0,
        reviewRecommendedSize: 0,
        totalItemCount: 0,
        safeItemCount: 0,
        reviewItemCount: 0,
        lastScanDate: nil,
        coverageTitles: [],
        topOpportunities: [],
        resultsMayBeStale: false,
        scannerWarnings: [],
        folderAccessLimited: false
    )
}

enum SmartScanAggregator {
    static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func build(
        space: [SpaceCategory],
        large: [StorageItem],
        dupes: [DuplicateGroup],
        orphans: [LeftoverItem],
        appCount: Int,
        appBytes: Int64,
        coverageTitles: [String],
        warnings: [String],
        lastScanDate: Date?,
        resultsMayBeStale: Bool
    ) -> (summaries: [SmartScanCategoryResult], summary: SmartScanSummary) {
        let spaceItems = space.flatMap(\.items)
        let spaceBytes = spaceItems.reduce(Int64(0)) { $0 + $1.byteSize }
        let spaceSafety = safetyForSpaceItems(spaceItems)
        let spaceRecoverable = spaceItems.filter { !$0.isSensitive }.reduce(Int64(0)) { $0 + $1.byteSize }

        let largeBytes = large.reduce(Int64(0)) { $0 + $1.byteSize }

        let dupeRecoverable = dupes.reduce(Int64(0)) { $0 + $1.recoverableBytes }
        let dupeGroupCount = dupes.count

        let orphanBytes = orphans.reduce(Int64(0)) { $0 + $1.byteSize }

        let summaries: [SmartScanCategoryResult] = [
            SmartScanCategoryResult(
                id: "space",
                title: "Space Cleaner",
                systemImage: "internaldrive",
                totalBytes: spaceBytes,
                recoverableBytes: spaceRecoverable,
                itemCount: spaceItems.count,
                progress: spaceBytes == 0 ? 0.05 : 0.85,
                destination: .spaceCleaner,
                safety: spaceSafety,
                explanation: "Caches, logs, and AI tool data found in folders you authorized.",
                statusDetail: nil
            ),
            SmartScanCategoryResult(
                id: "large",
                title: "Large Files",
                systemImage: "doc.on.doc",
                totalBytes: largeBytes,
                recoverableBytes: largeBytes,
                itemCount: large.count,
                progress: large.isEmpty ? 0.05 : 0.7,
                destination: .largeFiles,
                safety: .review,
                explanation: "Files larger than 50 MB found in authorized folders.",
                statusDetail: nil
            ),
            SmartScanCategoryResult(
                id: "dupes",
                title: "Duplicates",
                systemImage: "rectangle.on.rectangle",
                totalBytes: dupeRecoverable,
                recoverableBytes: dupeRecoverable,
                itemCount: dupeGroupCount,
                progress: dupes.isEmpty ? 0.05 : 0.55,
                destination: .duplicates,
                safety: .review,
                explanation: "Files with identical content found in authorized folders. Recoverable size keeps one copy.",
                statusDetail: nil
            ),
            SmartScanCategoryResult(
                id: "orphans",
                title: "App Leftovers",
                systemImage: "tray",
                totalBytes: orphanBytes,
                recoverableBytes: orphanBytes,
                itemCount: orphans.count,
                progress: orphans.isEmpty ? 0.05 : 0.5,
                destination: .orphans,
                safety: .review,
                explanation: "Files that may belong to applications that are no longer installed.",
                statusDetail: nil
            ),
            SmartScanCategoryResult(
                id: "apps",
                title: "Applications",
                systemImage: "square.grid.2x2",
                totalBytes: appBytes,
                recoverableBytes: 0,
                itemCount: appCount,
                progress: 0.4,
                destination: .applications,
                safety: .informational,
                explanation: "Installed applications. Review apps you may no longer need — not counted as automatic recovery.",
                statusDetail: nil
            ),
        ].sorted(by: categorySort)

        // Deduped global recoverables (apps excluded).
        var claimed = Set<String>()
        var safeBytes: Int64 = 0
        var reviewBytes: Int64 = 0
        var safeCount = 0
        var reviewCount = 0

        for item in spaceItems {
            guard !item.isSensitive else { continue }
            let key = canonicalPath(item.url)
            guard claimed.insert(key).inserted else { continue }
            if contributesAsSafe(item) {
                safeBytes += item.byteSize
                safeCount += 1
            } else {
                reviewBytes += item.byteSize
                reviewCount += 1
            }
        }

        for item in large {
            let key = canonicalPath(item.url)
            guard claimed.insert(key).inserted else { continue }
            reviewBytes += item.byteSize
            reviewCount += 1
        }

        for group in dupes {
            let keepID = group.keepID ?? group.files.first?.id
            for file in group.files where file.id != keepID {
                let key = canonicalPath(file.url)
                guard claimed.insert(key).inserted else { continue }
                reviewBytes += file.byteSize
                reviewCount += 1
            }
        }

        for item in orphans {
            let key = canonicalPath(item.url)
            guard claimed.insert(key).inserted else { continue }
            reviewBytes += item.byteSize
            reviewCount += 1
        }

        let opportunities = summaries
            .filter { $0.id != "apps" && $0.recoverableBytes > 0 }
            .prefix(4)
            .map {
                SmartScanOpportunity(
                    id: $0.id,
                    title: $0.title,
                    bytes: $0.recoverableBytes,
                    safety: $0.safety,
                    destination: $0.destination
                )
            }

        let folderLimited = coverageTitles.isEmpty
        let summary = SmartScanSummary(
            totalDiscoveredSize: safeBytes + reviewBytes,
            safeToRemoveSize: safeBytes,
            reviewRecommendedSize: reviewBytes,
            totalItemCount: safeCount + reviewCount,
            safeItemCount: safeCount,
            reviewItemCount: reviewCount,
            lastScanDate: lastScanDate,
            coverageTitles: coverageTitles,
            topOpportunities: Array(opportunities),
            resultsMayBeStale: resultsMayBeStale,
            scannerWarnings: warnings,
            folderAccessLimited: folderLimited
        )

        return (summaries, summary)
    }

    private static func contributesAsSafe(_ item: StorageItem) -> Bool {
        guard !item.isSensitive, item.isSelected else { return false }

        let category = item.category.lowercased()
        let name = item.name.lowercased()

        // Whole Application Support trees are never auto-safe.
        if category.contains("application support") {
            return false
        }
        if name.contains("application support"), !name.contains("cache") {
            return false
        }

        // Authorized caches / logs.
        if category.contains("cache") || category.contains("log") {
            return true
        }

        // AI catalog: selected non-sensitive cache/log-style entries.
        if ["Cursor", "Codex", "Claude", "Ollama", "LM Studio"].contains(item.category) {
            return name.contains("cache") || name.contains("log") || name.contains("gpucache") || name.contains("gpu cache")
        }

        return false
    }

    private static func safetyForSpaceItems(_ items: [StorageItem]) -> SmartScanCategorySafety {
        let relevant = items.filter { !$0.isSensitive }
        guard !relevant.isEmpty else { return .safe }
        let hasSafe = relevant.contains { contributesAsSafe($0) }
        let hasReview = relevant.contains { !contributesAsSafe($0) }
        if hasSafe && hasReview { return .mixed }
        if hasSafe { return .safe }
        return .review
    }

    private static func categorySort(_ lhs: SmartScanCategoryResult, _ rhs: SmartScanCategoryResult) -> Bool {
        // Safe + large first, then by recoverable size; apps last.
        if lhs.id == "apps" { return false }
        if rhs.id == "apps" { return true }
        let lhsScore = sortScore(lhs)
        let rhsScore = sortScore(rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return lhs.recoverableBytes > rhs.recoverableBytes
    }

    private static func sortScore(_ category: SmartScanCategoryResult) -> Int {
        let sizeBoost = category.recoverableBytes > 100 * 1024 * 1024 ? 2 : 0
        switch category.safety {
        case .safe: return 30 + sizeBoost
        case .mixed: return 20 + sizeBoost
        case .review: return 15 + sizeBoost
        case .informational: return 0
        }
    }
}
