//
//  SpaceCleanerScanner.swift
//  mac_cleaner
//

import Foundation

struct SpaceCleanerScanner: Sendable {
    let scope: ScanScope

    func scan() -> [SpaceCategory] {
        var categories: [SpaceCategory] = []
        var claimed = Set<String>()

        for group in SpaceCatalogGroup.allCases {
            if Task.isCancelled { return categories }
            let items = SpaceCatalogScanner.scan(
                entries: group.entries,
                home: scope.home,
                urlIfAccessible: { scope.urlIfAccessible($0) }
            )
            for item in items {
                claimed.insert(SmartScanAggregator.canonicalPath(item.url))
            }
            guard !items.isEmpty else { continue }
            categories.append(
                SpaceCategory(
                    id: group.id,
                    title: group.title,
                    subtitle: group.subtitle,
                    systemImage: group.systemImage,
                    items: items,
                    isExpanded: true
                )
            )
        }

        if let caches = scanDirectoryCategory(
            id: "caches",
            title: "Authorized Caches",
            subtitle: "Other cache folders you granted access to",
            systemImage: "externaldrive",
            kind: .caches,
            excluding: claimed
        ) {
            categories.append(caches)
        }

        if let logs = scanDirectoryCategory(
            id: "logs",
            title: "Authorized Logs",
            subtitle: "Other log folders you granted access to",
            systemImage: "doc.text",
            kind: .logs,
            excluding: claimed
        ) {
            categories.append(logs)
        }

        if let support = scanShallowChildren(
            id: "support-large",
            title: "Application Support (large)",
            subtitle: "Large items in granted Application Support",
            systemImage: "folder",
            kind: .applicationSupport,
            minimumBytes: 20 * 1024 * 1024,
            excluding: claimed
        ) {
            categories.append(support)
        }

        return categories
    }

    private func scanDirectoryCategory(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        kind: GrantedFolder.Kind,
        excluding claimed: Set<String>
    ) -> SpaceCategory? {
        let roots = scope.roots(for: kind)
        let fallback = scope.rootsMatchingPathComponent(kind == .caches ? "Caches" : "Logs")
        let targets = roots.isEmpty ? fallback : roots
        guard !targets.isEmpty else { return nil }

        var items: [StorageItem] = []
        for root in targets {
            if Task.isCancelled { return nil }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                let key = SmartScanAggregator.canonicalPath(url)
                if claimed.contains(key) { continue }
                if claimed.contains(where: { key.hasPrefix($0 + "/") || $0.hasPrefix(key + "/") }) {
                    continue
                }

                let size = FileSizeCalculator.size(of: url, maxDepth: 4)
                guard size > 64 * 1024 else { continue }
                items.append(
                    StorageItem(
                        url: url,
                        category: title,
                        byteSize: size,
                        isSelected: true,
                        isSensitive: PathNormalization.isSensitivePath(url),
                        modified: FileSizeCalculator.modificationDate(of: url)
                    )
                )
            }
        }

        guard !items.isEmpty else { return nil }
        return SpaceCategory(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            items: items.sorted { $0.byteSize > $1.byteSize }
        )
    }

    private func scanShallowChildren(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        kind: GrantedFolder.Kind,
        minimumBytes: Int64,
        excluding claimed: Set<String>
    ) -> SpaceCategory? {
        let roots = scope.roots(for: kind)
        guard !roots.isEmpty else { return nil }

        var items: [StorageItem] = []
        for root in roots {
            if Task.isCancelled { return nil }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in contents {
                let key = SmartScanAggregator.canonicalPath(url)
                if claimed.contains(key) { continue }
                if claimed.contains(where: { key.hasPrefix($0 + "/") || $0.hasPrefix(key + "/") }) {
                    continue
                }

                let size = FileSizeCalculator.size(of: url, maxDepth: 3)
                guard size >= minimumBytes else { continue }
                items.append(
                    StorageItem(
                        url: url,
                        category: title,
                        byteSize: size,
                        isSelected: false,
                        isSensitive: PathNormalization.isSensitivePath(url)
                    )
                )
            }
        }
        guard !items.isEmpty else { return nil }
        return SpaceCategory(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            items: items.sorted { $0.byteSize > $1.byteSize }
        )
    }
}
