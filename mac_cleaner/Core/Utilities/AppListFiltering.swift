//
//  AppListFiltering.swift
//  mac_cleaner
//
//  Pure filter/sort helpers for the Applications list.
//

import Foundation

enum AppListFiltering {
    static let largeThresholdBytes: Int64 = 500 * 1024 * 1024

    static func matches(
        app: InstalledApp,
        filter: AppListFilter,
        searchText: String,
        unusedThreshold: UnusedThreshold,
        totalDiscoveredSize: Int64
    ) -> Bool {
        guard !app.isSystemApp else { return false }

        if !searchText.isEmpty {
            let query = searchText
            let matchesName = app.name.localizedCaseInsensitiveContains(query)
            let matchesBundle = app.bundleIdentifier.localizedCaseInsensitiveContains(query)
            guard matchesName || matchesBundle else { return false }
        }

        switch filter {
        case .all:
            return true
        case .selected:
            return app.isSelected
        case .large:
            // Prefer total discovered storage when a leftover scan exists.
            return max(app.byteSize, totalDiscoveredSize) >= largeThresholdBytes
        case .unused:
            guard let opened = app.lastOpenedDate else { return false }
            return Date().timeIntervalSince(opened) >= unusedThreshold.timeInterval
        }
    }

    static func sorted(
        _ apps: [InstalledApp],
        by sort: AppListSort,
        totalSize: (InstalledApp) -> Int64
    ) -> [InstalledApp] {
        var list = apps
        switch sort {
        case .name:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .largestApp:
            list.sort {
                if $0.byteSize == $1.byteSize {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.byteSize > $1.byteSize
            }
        case .largestTotal:
            list.sort {
                let lhs = totalSize($0)
                let rhs = totalSize($1)
                if lhs == rhs {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhs > rhs
            }
        case .leastRecentlyOpened:
            list.sort {
                let lhs = $0.lastOpenedDate ?? .distantFuture
                let rhs = $1.lastOpenedDate ?? .distantFuture
                if lhs == rhs {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                // Unknown dates sort last (distantFuture), known older dates first.
                return lhs < rhs
            }
        }
        return list
    }
}
