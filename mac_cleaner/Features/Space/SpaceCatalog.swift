//
//  SpaceCatalog.swift
//  mac_cleaner
//
//  Named junk catalogs. An entry is only scanned when a security-scoped
//  bookmark already covers its path — never by walking the real home alone.
//

import Foundation

struct SpaceCatalogEntry: Equatable, Sendable {
    let title: String
    let relativePath: String
    let category: String
    let isSensitive: Bool
    let defaultSelected: Bool

    /// Sensitive rows stay unchecked even if a catalog marks them selected.
    var effectiveDefaultSelected: Bool {
        isSensitive ? false : defaultSelected
    }
}

enum SpaceCatalogGroup: String, CaseIterable, Identifiable, Sendable {
    case apple
    case developer
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple Data"
        case .developer: return "Developer Data"
        case .ai: return "AI Tool Data"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return "iPhone backups, Mail downloads, and browser caches"
        case .developer: return "Xcode, Homebrew, npm, and Docker — review large disks"
        case .ai: return "Claude, Codex, Cursor, and related caches"
        }
    }

    var systemImage: String {
        switch self {
        case .apple: return "apple.logo"
        case .developer: return "hammer"
        case .ai: return "brain"
        }
    }

    var entries: [SpaceCatalogEntry] {
        switch self {
        case .apple: return AppleJunkCatalog.entries
        case .developer: return DeveloperJunkCatalog.entries
        case .ai: return AIJunkCatalog.entries
        }
    }
}

enum SpaceCatalogScanner: Sendable {
    /// Testable entry point — no BookmarkStore required.
    static func scan(
        entries: [SpaceCatalogEntry],
        home: String,
        urlIfAccessible: (String) -> URL?,
        sizeOf: (URL) -> Int64 = { FileSizeCalculator.size(of: $0) },
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        modified: (URL) -> Date? = { FileSizeCalculator.modificationDate(of: $0) }
    ) -> [StorageItem] {
        var items: [StorageItem] = []

        for entry in entries {
            let fullPath = (home as NSString).appendingPathComponent(entry.relativePath)
            guard let url = urlIfAccessible(fullPath) else { continue }
            guard exists(url) else { continue }

            let size = sizeOf(url)
            guard size > 0 else { continue }

            items.append(
                StorageItem(
                    url: url,
                    name: entry.title,
                    category: entry.category,
                    byteSize: size,
                    isSelected: entry.effectiveDefaultSelected,
                    isSensitive: entry.isSensitive,
                    isRootOwned: FileOwnership.isOwnedByRoot(url),
                    modified: modified(url)
                )
            )
        }

        return items.sorted { $0.byteSize > $1.byteSize }
    }
}

enum SpaceCatalogSafety {
    static func isReviewOnly(name: String, category: String) -> Bool {
        let haystack = "\(name) \(category)".lowercased()
        return haystack.contains("backup")
            || haystack.contains("archive")
            || haystack.contains("docker")
            || haystack.contains("orbstack")
            || haystack.contains("mail")
            || haystack.contains("userdata")
            || haystack.contains("simulator")
    }

    static func looksRegenerable(name: String, category: String) -> Bool {
        let haystack = "\(name) \(category)".lowercased()
        if isReviewOnly(name: name, category: category) { return false }
        return haystack.contains("cache")
            || haystack.contains("log")
            || haystack.contains("deriveddata")
            || haystack.contains("gpucache")
            || haystack.contains("gpu cache")
            || haystack.contains("documentation")
    }
}
