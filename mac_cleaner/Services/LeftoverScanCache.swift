//
//  LeftoverScanCache.swift
//  mac_cleaner
//
//  Persists leftover scan results so Applications can show estimated totals
//  without rescanning every launch. Invalidates on scope / sensitivity / app change.
//

import Foundation

struct CachedLeftoverPayload: Codable, Hashable {
    var urlPath: String
    var kind: LeftoverKind
    var byteSize: Int64
    var matchConfidence: MatchConfidence
    var matchReason: MatchReason
    var safety: SafetyClassification
    var isSharedOrPossiblyShared: Bool
    var relatedInstalledAppNames: [String]
    var isSensitive: Bool
}

struct CachedLeftoverScan: Codable, Hashable {
    var appPath: String
    var bundleID: String
    var sensitivity: String
    var bookmarkScopeSignature: String
    var scannedAt: Date
    var appContentModification: Date?
    var items: [CachedLeftoverPayload]
    var searchedFolderTitles: [String]
}

final class LeftoverScanCache {
    static let shared = LeftoverScanCache()

    private let defaultsKey = "mas.leftoverScanCache.v1"
    private var entries: [String: CachedLeftoverScan] = [:]
    private let lock = NSLock()

    init() {
        load()
    }

    static func scopeSignature(bookmarks: BookmarkStore, sensitivity: LeftoverSensitivity) -> String {
        let folders = bookmarks.folders.map(\.path).sorted().joined(separator: "|")
        return "\(sensitivity.rawValue)::\(folders)"
    }

    static func cacheKey(for app: InstalledApp) -> String {
        "\(app.bundleIdentifier)|\(app.path.path)"
    }

    func cachedScan(
        for app: InstalledApp,
        bookmarks: BookmarkStore,
        sensitivity: LeftoverSensitivity
    ) -> CachedLeftoverScan? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[Self.cacheKey(for: app)] else { return nil }
        let scope = Self.scopeSignature(bookmarks: bookmarks, sensitivity: sensitivity)
        guard entry.bookmarkScopeSignature == scope else { return nil }
        guard entry.bundleID == app.bundleIdentifier, entry.appPath == app.path.path else { return nil }

        let currentMod = Self.appModificationDate(for: app.path)
        if let cachedMod = entry.appContentModification, let currentMod, cachedMod != currentMod {
            return nil
        }
        return entry
    }

    func store(
        _ result: LeftoverScanResult,
        for app: InstalledApp,
        bookmarks: BookmarkStore,
        sensitivity: LeftoverSensitivity
    ) {
        let payload = CachedLeftoverScan(
            appPath: app.path.path,
            bundleID: app.bundleIdentifier,
            sensitivity: sensitivity.rawValue,
            bookmarkScopeSignature: Self.scopeSignature(bookmarks: bookmarks, sensitivity: sensitivity),
            scannedAt: result.scannedAt,
            appContentModification: Self.appModificationDate(for: app.path),
            items: result.items.map {
                CachedLeftoverPayload(
                    urlPath: $0.url.path,
                    kind: $0.kind,
                    byteSize: $0.byteSize,
                    matchConfidence: $0.matchConfidence,
                    matchReason: $0.matchReason,
                    safety: $0.safety,
                    isSharedOrPossiblyShared: $0.isSharedOrPossiblyShared,
                    relatedInstalledAppNames: $0.relatedInstalledAppNames,
                    isSensitive: $0.isSensitive || $0.safety == .sensitive
                )
            },
            searchedFolderTitles: result.searchedFolderTitles
        )
        lock.lock()
        entries[Self.cacheKey(for: app)] = payload
        persistLocked()
        lock.unlock()
    }

    func invalidateAll() {
        lock.lock()
        entries.removeAll()
        persistLocked()
        lock.unlock()
    }

    func invalidate(appIDKey: String) {
        lock.lock()
        entries.removeValue(forKey: appIDKey)
        persistLocked()
        lock.unlock()
    }

    func items(from cache: CachedLeftoverScan) -> [LeftoverItem] {
        cache.items.map { payload in
            LeftoverItem(
                url: URL(fileURLWithPath: payload.urlPath),
                kind: payload.kind,
                byteSize: payload.byteSize,
                isSelected: nil,
                isSensitive: payload.isSensitive,
                matchConfidence: payload.matchConfidence,
                matchReason: payload.matchReason,
                safety: payload.safety,
                isSharedOrPossiblyShared: payload.isSharedOrPossiblyShared,
                relatedInstalledAppNames: payload.relatedInstalledAppNames
            )
        }
    }

    private static func appModificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: CachedLeftoverScan].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persistLocked() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
