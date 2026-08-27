//
//  AIJunkCatalog.swift
//  mac_cleaner
//

import Foundation

enum AIJunkCatalog {
    struct Entry {
        let title: String
        let relativePath: String
        let category: String
        let isSensitive: Bool
        let defaultSelected: Bool
    }

    static let entries: [Entry] = [
        // Cursor
        Entry(title: "Cursor Caches", relativePath: "Library/Caches/Cursor", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor ToDesktop Cache", relativePath: "Library/Caches/com.todesktop.230313mzl4w4u92", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor Application Support Cache", relativePath: "Library/Application Support/Cursor/Cache", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor CachedData", relativePath: "Library/Application Support/Cursor/CachedData", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor GPUCache", relativePath: "Library/Application Support/Cursor/GPUCache", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor Code Cache", relativePath: "Library/Application Support/Cursor/Code Cache", category: "Cursor", isSensitive: false, defaultSelected: true),
        Entry(title: "Cursor Agent Transcripts", relativePath: ".cursor/projects", category: "Cursor", isSensitive: true, defaultSelected: false),

        // Codex
        Entry(title: "Codex Cache", relativePath: "Library/Caches/Codex", category: "Codex", isSensitive: false, defaultSelected: true),
        Entry(title: "Codex App Cache", relativePath: "Library/Caches/com.openai.codex", category: "Codex", isSensitive: false, defaultSelected: true),
        Entry(title: "Codex Logs", relativePath: "Library/Logs/com.openai.codex", category: "Codex", isSensitive: false, defaultSelected: true),
        Entry(title: "Codex Home Cache", relativePath: ".codex/cache", category: "Codex", isSensitive: false, defaultSelected: true),
        Entry(title: "Codex Auth", relativePath: ".codex/auth.json", category: "Codex", isSensitive: true, defaultSelected: false),
        Entry(title: "Codex Config", relativePath: ".codex/config.toml", category: "Codex", isSensitive: true, defaultSelected: false),

        // Claude
        Entry(title: "Claude Application Support", relativePath: "Library/Application Support/Claude", category: "Claude", isSensitive: false, defaultSelected: true),
        Entry(title: "Claude Caches", relativePath: "Library/Caches/com.anthropic.claudefordesktop", category: "Claude", isSensitive: false, defaultSelected: true),
        Entry(title: "Claude Code Home", relativePath: ".claude", category: "Claude", isSensitive: true, defaultSelected: false),

        // Ollama / LM Studio
        Entry(title: "Ollama Logs", relativePath: ".ollama/logs", category: "Ollama", isSensitive: false, defaultSelected: true),
        Entry(title: "Ollama Cache", relativePath: "Library/Caches/ollama", category: "Ollama", isSensitive: false, defaultSelected: true),
        Entry(title: "LM Studio Logs", relativePath: "Library/Application Support/LM Studio/logs", category: "LM Studio", isSensitive: false, defaultSelected: true),
    ]

    static func scan(bookmarks: BookmarkStore) -> [StorageItem] {
        let home = BookmarkStore.realUserHomePath()
        var items: [StorageItem] = []

        for entry in entries {
            let fullPath = (home as NSString).appendingPathComponent(entry.relativePath)
            guard let url = bookmarks.urlIfAccessible(fullPath) else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            let size = FileSizeCalculator.size(of: url)
            guard size > 0 else { continue }

            items.append(
                StorageItem(
                    url: url,
                    name: entry.title,
                    category: entry.category,
                    byteSize: size,
                    isSelected: entry.defaultSelected,
                    isSensitive: entry.isSensitive,
                    modified: FileSizeCalculator.modificationDate(of: url)
                )
            )
        }

        return items.sorted { $0.byteSize > $1.byteSize }
    }
}
