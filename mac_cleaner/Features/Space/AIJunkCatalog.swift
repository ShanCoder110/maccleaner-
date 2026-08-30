//
//  AIJunkCatalog.swift
//  mac_cleaner
//

import Foundation

enum AIJunkCatalog {
    static let entries: [SpaceCatalogEntry] = [
        SpaceCatalogEntry(title: "Cursor Caches", relativePath: "Library/Caches/Cursor", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor ToDesktop Cache", relativePath: "Library/Caches/com.todesktop.230313mzl4w4u92", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor Application Support Cache", relativePath: "Library/Application Support/Cursor/Cache", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor CachedData", relativePath: "Library/Application Support/Cursor/CachedData", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor GPUCache", relativePath: "Library/Application Support/Cursor/GPUCache", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor Code Cache", relativePath: "Library/Application Support/Cursor/Code Cache", category: "Cursor", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Cursor Agent Transcripts", relativePath: ".cursor/projects", category: "Cursor", isSensitive: true, defaultSelected: false),

        SpaceCatalogEntry(title: "Codex Cache", relativePath: "Library/Caches/Codex", category: "Codex", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Codex App Cache", relativePath: "Library/Caches/com.openai.codex", category: "Codex", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Codex Logs", relativePath: "Library/Logs/com.openai.codex", category: "Codex", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Codex Home Cache", relativePath: ".codex/cache", category: "Codex", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Codex Auth", relativePath: ".codex/auth.json", category: "Codex", isSensitive: true, defaultSelected: false),
        SpaceCatalogEntry(title: "Codex Config", relativePath: ".codex/config.toml", category: "Codex", isSensitive: true, defaultSelected: false),

        SpaceCatalogEntry(title: "Claude Application Support", relativePath: "Library/Application Support/Claude", category: "Claude", isSensitive: false, defaultSelected: false),
        SpaceCatalogEntry(title: "Claude Caches", relativePath: "Library/Caches/com.anthropic.claudefordesktop", category: "Claude", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Claude Code Home", relativePath: ".claude", category: "Claude", isSensitive: true, defaultSelected: false),

        SpaceCatalogEntry(title: "Ollama Logs", relativePath: ".ollama/logs", category: "Ollama", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "Ollama Cache", relativePath: "Library/Caches/ollama", category: "Ollama", isSensitive: false, defaultSelected: true),
        SpaceCatalogEntry(title: "LM Studio Logs", relativePath: "Library/Application Support/LM Studio/logs", category: "LM Studio", isSensitive: false, defaultSelected: true)
    ]
}
