//
//  CleaningService.swift
//  mac_cleaner
//
//  Trash-only deletion scoped to security-scoped bookmarks and selected apps.
//

import Foundation
import AppKit

struct CleaningService {
    let bookmarks: BookmarkStore
    let log: ActivityLogStore

    func trash(urls: [URL], progress: ((Double) -> Void)? = nil) async -> CleanResult {
        var result = CleanResult()
        let unique = Array(Set(urls.map(\.standardizedFileURL)))
        guard !unique.isEmpty else { return result }

        for (index, url) in unique.enumerated() {
            let fraction = Double(index + 1) / Double(unique.count)
            await MainActor.run { progress?(fraction) }

            guard isAllowed(url) else {
                let message = "Skipped path outside authorized folders: \(url.path)"
                result.errors.append(message)
                await MainActor.run {
                    log.log(.error, message, path: url.path)
                }
                continue
            }

            let size = FileSizeCalculator.size(of: url)
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                result.trashedCount += 1
                result.freedBytes += size
                await MainActor.run {
                    log.log(.clean, "Moved to Trash: \(url.lastPathComponent)", path: url.path)
                }
            } catch {
                let message = "Could not trash \(url.lastPathComponent): \(error.localizedDescription)"
                result.errors.append(message)
                await MainActor.run {
                    log.log(.error, message, path: url.path)
                }
            }
        }

        return result
    }

    func isAllowed(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL

        // Resolve symlinks and reject escapes.
        let resolved = standardized.resolvingSymlinksInPath()
        if resolved.path != standardized.path && !bookmarks.containsPath(resolved.path) {
            // Allow .app bundles selected for uninstall even if not under a bookmark.
            if standardized.pathExtension == "app", isUserApplication(standardized) {
                return true
            }
            if !bookmarks.containsPath(standardized.path) {
                return false
            }
        }

        if standardized.pathExtension == "app", isUserApplication(standardized) {
            return true
        }

        return bookmarks.containsPath(standardized.path) || bookmarks.containsPath(resolved.path)
    }

    private func isUserApplication(_ url: URL) -> Bool {
        let path = url.path
        if path.hasPrefix("/System") { return false }
        if path.hasPrefix("/Applications") || path.hasPrefix(BookmarkStore.realUserHomePath() + "/Applications") {
            return true
        }
        return false
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
