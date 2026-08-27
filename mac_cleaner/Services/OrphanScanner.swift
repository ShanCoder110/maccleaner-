//
//  OrphanScanner.swift
//  mac_cleaner
//

import Foundation

struct OrphanScanner {
    let bookmarks: BookmarkStore

    func scan(installedApps: [InstalledApp]) -> [LeftoverItem] {
        let roots = bookmarks.accessibleRootURLs
        guard !roots.isEmpty else { return [] }

        let identifiers = Set(installedApps.map { $0.bundleIdentifier.normalizedForMatching() })
        let names = Set(installedApps.map { $0.name.normalizedForMatching() }.filter { $0.count >= 5 })

        var items: [LeftoverItem] = []

        for root in roots {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            // Prefer scanning one level of known library-style folders
            let candidates: [URL]
            if root.lastPathComponent == "Caches"
                || root.lastPathComponent == "Logs"
                || root.lastPathComponent == "Application Support"
                || root.lastPathComponent == "Preferences"
                || root.lastPathComponent == "Containers" {
                candidates = contents
            } else {
                candidates = contents.flatMap { child -> [URL] in
                    let name = child.lastPathComponent
                    if ["Caches", "Logs", "Application Support", "Preferences", "Containers"].contains(name) {
                        return (try? FileManager.default.contentsOfDirectory(at: child, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                    }
                    return []
                }
            }

            for url in candidates {
                let key = url.deletingPathExtension().lastPathComponent.normalizedForMatching()
                guard key.count >= 5 else { continue }
                let matchedApp = identifiers.contains(where: { key.contains($0) || $0.contains(key) })
                    || names.contains(where: { key.contains($0) || $0.contains(key) })
                if matchedApp { continue }

                let kind = PathNormalization.kind(for: url)
                // Orphan safety: default-select only caches/logs
                let autoSelect = kind == .caches || kind == .logs
                let size = FileSizeCalculator.size(of: url, maxDepth: 4)
                guard size > 32 * 1024 else { continue }

                items.append(
                    LeftoverItem(
                        url: url,
                        kind: kind,
                        byteSize: size,
                        isSelected: autoSelect,
                        isSensitive: !autoSelect || PathNormalization.isSensitivePath(url)
                    )
                )
            }
        }

        return items.sorted { $0.byteSize > $1.byteSize }
    }
}
