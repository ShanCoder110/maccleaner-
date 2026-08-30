//
//  ScanScope.swift
//  mac_cleaner
//
//  Main-actor snapshot of granted folders. Scanners take this value, never BookmarkStore.
//

import Foundation

struct ScanFolderSnapshot: Sendable, Hashable {
    let kind: GrantedFolder.Kind
    let url: URL
}

struct ScanScope: Sendable {
    let home: String
    let roots: [URL]
    let coverageTitles: [String]
    let folders: [ScanFolderSnapshot]

    var isEmpty: Bool { roots.isEmpty }

    func urlIfAccessible(_ path: String) -> URL? {
        let standardized = (path as NSString).standardizingPath
        for root in roots {
            if standardized == root.path || standardized.hasPrefix(root.path + "/") {
                return URL(fileURLWithPath: standardized)
            }
        }
        return nil
    }

    func roots(for kind: GrantedFolder.Kind) -> [URL] {
        folders.filter { $0.kind == kind }.map(\.url)
    }

    func rootsMatchingPathComponent(_ component: String) -> [URL] {
        roots.filter { $0.path.localizedCaseInsensitiveContains(component) }
    }

    @MainActor
    static func snapshot(from bookmarks: BookmarkStore) -> ScanScope {
        let folders = bookmarks.folders.compactMap { folder -> ScanFolderSnapshot? in
            guard let url = bookmarks.startAccess(for: folder.id) else { return nil }
            return ScanFolderSnapshot(kind: folder.kind, url: url)
        }
        return ScanScope(
            home: BookmarkStore.realUserHomePath(),
            roots: bookmarks.accessibleRootURLs,
            coverageTitles: bookmarks.folders.map(\.kind.title).sorted(),
            folders: folders
        )
    }
}

enum ScanTask {
    /// Runs blocking I/O off the main actor and forwards parent cancellation.
    static func detached<T: Sendable>(
        _ work: @escaping @Sendable () -> T
    ) async -> T {
        let task = Task.detached(priority: .userInitiated) {
            work()
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
