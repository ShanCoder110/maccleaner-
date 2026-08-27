//
//  SpaceCleanerScanner.swift
//  mac_cleaner
//

import Foundation

struct SpaceCleanerScanner {
    let bookmarks: BookmarkStore

    func scan() -> [SpaceCategory] {
        var categories: [SpaceCategory] = []

        if let caches = scanDirectoryCategory(
            id: "caches",
            title: "Authorized Caches",
            subtitle: "Cache folders you granted access to",
            systemImage: "externaldrive",
            kind: .caches
        ) {
            categories.append(caches)
        }

        if let logs = scanDirectoryCategory(
            id: "logs",
            title: "Authorized Logs",
            subtitle: "Log folders you granted access to",
            systemImage: "doc.text",
            kind: .logs
        ) {
            categories.append(logs)
        }

        let aiItems = AIJunkCatalog.scan(bookmarks: bookmarks)
        if !aiItems.isEmpty {
            categories.append(
                SpaceCategory(
                    id: "ai",
                    title: "AI Tool Data",
                    subtitle: "Claude, Codex, Cursor, and related caches",
                    systemImage: "brain",
                    items: aiItems
                )
            )
        }

        if let support = scanShallowChildren(
            id: "support-large",
            title: "Application Support (large)",
            subtitle: "Large items in granted Application Support",
            systemImage: "folder",
            kind: .applicationSupport,
            minimumBytes: 20 * 1024 * 1024
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
        kind: GrantedFolder.Kind
    ) -> SpaceCategory? {
        let roots = bookmarks.folders.filter { $0.kind == kind }.compactMap { bookmarks.startAccess(for: $0.id) }
        let fallback = bookmarks.accessibleRootURLs.filter {
            $0.path.localizedCaseInsensitiveContains(kind == .caches ? "Caches" : "Logs")
        }
        let targets = roots.isEmpty ? fallback : roots
        guard !targets.isEmpty else { return nil }

        var items: [StorageItem] = []
        for root in targets {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
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
        minimumBytes: Int64
    ) -> SpaceCategory? {
        let roots = bookmarks.folders.filter { $0.kind == kind }.compactMap { bookmarks.startAccess(for: $0.id) }
        guard !roots.isEmpty else { return nil }

        var items: [StorageItem] = []
        for root in roots {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in contents {
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
