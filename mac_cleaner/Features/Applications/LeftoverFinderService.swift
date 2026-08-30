//
//  LeftoverFinderService.swift
//  mac_cleaner
//
//  Scoped leftover matching — only searches authorized bookmark roots.
//  Separates match confidence from deletion safety.
//

import Foundation

struct LeftoverScanResult: Sendable {
    var items: [LeftoverItem]
    var searchedFolderTitles: [String]
    var scannedAt: Date
}

struct LeftoverFinderService {
    let bookmarks: BookmarkStore

    func findLeftovers(
        for app: InstalledApp,
        sensitivity: LeftoverSensitivity = .enhanced,
        allInstalledApps: [InstalledApp] = []
    ) -> LeftoverScanResult {
        findLeftovers(
            for: app,
            sensitivity: sensitivity,
            allInstalledApps: allInstalledApps,
            roots: bookmarks.accessibleRootURLs,
            searchedFolderTitles: bookmarks.folders.map(\.kind.title).sorted()
        )
    }

    /// Snapshot-based entry point safe to call off the main actor.
    nonisolated static func findLeftovers(
        for app: InstalledApp,
        sensitivity: LeftoverSensitivity,
        allInstalledApps: [InstalledApp],
        roots: [URL],
        searchedFolderTitles: [String]
    ) -> LeftoverScanResult {
        var results: [URL: LeftoverItem] = [:]

        results[app.path.standardizedFileURL] = LeftoverItem(
            url: app.path,
            kind: .appBundle,
            byteSize: app.byteSize > 0 ? app.byteSize : FileSizeCalculator.size(of: app.path, maxDepth: 4),
            isRootOwned: FileOwnership.isOwnedByRoot(app.path),
            matchConfidence: .confirmed,
            matchReason: .appBundleItself,
            safety: .reviewRecommended,
            relatedInstalledAppNames: [app.name]
        )

        guard !roots.isEmpty else {
            return LeftoverScanResult(
                items: Array(results.values).sorted { $0.byteSize > $1.byteSize },
                searchedFolderTitles: searchedFolderTitles,
                scannedAt: Date()
            )
        }

        let matcher = AppMatcher(app: app, sensitivity: sensitivity)
        let otherApps = allInstalledApps.filter { $0.id != app.id && !$0.isSystemApp }

        for root in roots {
            scan(
                root: root,
                depth: 0,
                maxDepth: maxDepth(for: root),
                matcher: matcher,
                appName: app.name,
                into: &results
            )
        }

        var finalized: [LeftoverItem] = []
        for var item in results.values {
            if item.kind == .appBundle {
                finalized.append(item)
                continue
            }
            let sharers = otherApps.filter { other in
                AppMatcher(app: other, sensitivity: .deep).matches(
                    name: item.url.deletingPathExtension().lastPathComponent,
                    url: item.url
                ) != nil
            }
            if !sharers.isEmpty {
                item.isSharedOrPossiblyShared = true
                item.relatedInstalledAppNames = ([app.name] + sharers.map(\.name)).uniquedPreservingOrder()
                item.isSelected = false
                if item.matchConfidence == .confirmed {
                    item.matchConfidence = .likely
                }
            } else if item.relatedInstalledAppNames.isEmpty {
                item.relatedInstalledAppNames = [app.name]
            }
            if item.matchConfidence == .possible {
                item.isSelected = false
            }
            finalized.append(item)
        }

        let filtered: [LeftoverItem]
        switch sensitivity {
        case .strict:
            filtered = finalized.filter { $0.matchConfidence == .confirmed || $0.kind == .appBundle }
        case .enhanced:
            filtered = finalized.filter { $0.matchConfidence != .possible || $0.kind == .appBundle }
        case .deep:
            filtered = finalized
        }

        return LeftoverScanResult(
            items: filtered.sorted { $0.byteSize > $1.byteSize },
            searchedFolderTitles: searchedFolderTitles,
            scannedAt: Date()
        )
    }

    private func findLeftovers(
        for app: InstalledApp,
        sensitivity: LeftoverSensitivity,
        allInstalledApps: [InstalledApp],
        roots: [URL],
        searchedFolderTitles: [String]
    ) -> LeftoverScanResult {
        Self.findLeftovers(
            for: app,
            sensitivity: sensitivity,
            allInstalledApps: allInstalledApps,
            roots: roots,
            searchedFolderTitles: searchedFolderTitles
        )
    }

    nonisolated private static func maxDepth(for root: URL) -> Int {
        let path = root.path
        if path.hasSuffix("Library") || path.hasSuffix("Application Support") {
            return 2
        }
        return 1
    }

    nonisolated private static func scan(
        root: URL,
        depth: Int,
        maxDepth: Int,
        matcher: AppMatcher,
        appName: String,
        into results: inout [URL: LeftoverItem]
    ) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for itemURL in contents {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }

            let name = itemURL.deletingPathExtension().lastPathComponent
            if let hit = matcher.matches(name: name, url: itemURL) {
                let standardized = itemURL.standardizedFileURL
                if results[standardized] == nil {
                    let kind = PathNormalization.kind(for: standardized)
                    let safety = SafetyClassification.classify(kind: kind, url: standardized)
                    results[standardized] = LeftoverItem(
                        url: standardized,
                        kind: kind,
                        byteSize: FileSizeCalculator.size(of: standardized, maxDepth: 5),
                        isRootOwned: FileOwnership.isOwnedByRoot(standardized),
                        matchConfidence: hit.confidence,
                        matchReason: hit.reason,
                        safety: safety,
                        relatedInstalledAppNames: [appName]
                    )
                }
            }

            if values?.isDirectory == true, depth < maxDepth {
                let last = itemURL.lastPathComponent
                if last == "Caches" || last == "Logs" || last == "Preferences"
                    || last == "Application Support" || last == "Containers"
                    || last == "Group Containers" || last == "Saved Application State"
                    || last == "LaunchAgents" || depth > 0 {
                    scan(
                        root: itemURL,
                        depth: depth + 1,
                        maxDepth: maxDepth,
                        matcher: matcher,
                        appName: appName,
                        into: &results
                    )
                }
            }
        }
    }
}

private extension Array where Element == String {
    nonisolated func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in self where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
