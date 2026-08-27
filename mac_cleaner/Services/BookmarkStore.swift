//
//  BookmarkStore.swift
//  mac_cleaner
//
//  Persists security-scoped bookmarks for Mac App Store sandbox access.
//

import Foundation
import AppKit
import Combine
import Darwin

final class BookmarkStore: ObservableObject {
    @Published private(set) var folders: [GrantedFolder] = []
    private var bookmarkDataByID: [UUID: Data] = [:]
    private var activeURLs: [UUID: URL] = [:]

    private let foldersKey = "mas.grantedFolders"
    private let bookmarksKey = "mas.bookmarkData"

    init() {
        load()
    }

    var hasAnyAccess: Bool { !folders.isEmpty }

    var accessibleRootURLs: [URL] {
        folders.compactMap { startAccess(for: $0.id) }
    }

    func containsPath(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        return accessibleRootURLs.contains { root in
            standardized == root.path || standardized.hasPrefix(root.path + "/")
        }
    }

    func urlIfAccessible(_ path: String) -> URL? {
        let standardized = (path as NSString).standardizingPath
        for folder in folders {
            guard let root = startAccess(for: folder.id) else { continue }
            if standardized == root.path || standardized.hasPrefix(root.path + "/") {
                return URL(fileURLWithPath: standardized)
            }
        }
        return nil
    }

    @discardableResult
    func startAccess(for id: UUID) -> URL? {
        if let existing = activeURLs[id] {
            return existing
        }
        guard let data = bookmarkDataByID[id] else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else { return nil }
            if isStale {
                if let refreshed = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    bookmarkDataByID[id] = refreshed
                    persist()
                }
            }
            activeURLs[id] = url
            return url
        } catch {
            return nil
        }
    }

    func stopAllAccess() {
        for (_, url) in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeURLs.removeAll()
    }

    @discardableResult
    func addFolder(url: URL, kind: GrantedFolder.Kind) -> GrantedFolder? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        let standardized = url.standardizedFileURL.path
        if let existing = folders.first(where: { $0.path == standardized }) {
            bookmarkDataByID[existing.id] = data
            persist()
            return existing
        }

        let folder = GrantedFolder(
            id: UUID(),
            displayName: url.lastPathComponent,
            path: standardized,
            kind: kind
        )
        folders.append(folder)
        bookmarkDataByID[folder.id] = data
        persist()
        return folder
    }

    func removeFolder(id: UUID) {
        if let url = activeURLs.removeValue(forKey: id) {
            url.stopAccessingSecurityScopedResource()
        }
        folders.removeAll { $0.id == id }
        bookmarkDataByID.removeValue(forKey: id)
        persist()
    }

    /// Presents an open panel so the user can grant folder access.
    func requestFolderAccess(
        message: String,
        suggestedPath: String?,
        kind: GrantedFolder.Kind
    ) -> GrantedFolder? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Grant Access"
        panel.message = message
        panel.title = "Allow Folder Access"
        if let suggestedPath {
            panel.directoryURL = URL(fileURLWithPath: suggestedPath)
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        return addFolder(url: url, kind: kind)
    }

    func ensurePresetAccess(kind: GrantedFolder.Kind) -> GrantedFolder? {
        if let existing = folders.first(where: { $0.kind == kind }) {
            _ = startAccess(for: existing.id)
            return existing
        }
        guard let path = Self.suggestedPath(for: kind) else {
            return requestFolderAccess(
                message: "Choose a folder MacCleaner+ may scan and clean.",
                suggestedPath: BookmarkStore.realUserHomePath(),
                kind: kind
            )
        }
        return requestFolderAccess(
            message: "Grant access to \(kind.title) so the app can scan files you choose to manage.",
            suggestedPath: path,
            kind: kind
        )
    }

    static func realUserHomePath() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return "/Users/\(NSUserName())"
    }

    static func suggestedPath(for kind: GrantedFolder.Kind) -> String? {
        let home = realUserHomePath()
        switch kind {
        case .applicationSupport: return (home as NSString).appendingPathComponent("Library/Application Support")
        case .caches: return (home as NSString).appendingPathComponent("Library/Caches")
        case .logs: return (home as NSString).appendingPathComponent("Library/Logs")
        case .preferences: return (home as NSString).appendingPathComponent("Library/Preferences")
        case .containers: return (home as NSString).appendingPathComponent("Library/Containers")
        case .homeAI: return home
        case .downloads: return (home as NSString).appendingPathComponent("Downloads")
        case .documents: return (home as NSString).appendingPathComponent("Documents")
        case .desktop: return (home as NSString).appendingPathComponent("Desktop")
        case .custom: return home
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([GrantedFolder].self, from: data) {
            folders = decoded
        }
        if let map = defaults.dictionary(forKey: bookmarksKey) as? [String: Data] {
            for (key, value) in map {
                if let id = UUID(uuidString: key) {
                    bookmarkDataByID[id] = value
                }
            }
        }
        // Drop folders without bookmark data
        folders.removeAll { bookmarkDataByID[$0.id] == nil }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(folders) {
            defaults.set(data, forKey: foldersKey)
        }
        var map: [String: Data] = [:]
        for (id, data) in bookmarkDataByID {
            map[id.uuidString] = data
        }
        defaults.set(map, forKey: bookmarksKey)
    }
}
