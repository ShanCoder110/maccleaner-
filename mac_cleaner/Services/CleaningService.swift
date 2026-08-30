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

        // Filter URLs through allowlist before preparing scoped access
        let allowed = await MainActor.run { unique.filter { isAllowed($0) } }
        let blocked = unique.count - allowed.count
        if blocked > 0 {
            let message = "Blocked \(blocked) item\(blocked == 1 ? "" : "s") outside authorized folders."
            result.errors.append(message)
            await MainActor.run {
                log.log(.error, message)
            }
        }

        let prepared = await MainActor.run { prepareScopedURLs(for: allowed) }

        for (index, url) in prepared.enumerated() {
            let fraction = Double(index + 1) / Double(max(unique.count, 1))
            await MainActor.run { progress?(fraction) }

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
                let outcome = await MainActor.run { () -> RetryOutcome in
                    retryTrash(url: url, size: size, previousError: error)
                }
                switch outcome {
                case .succeeded(let freed):
                    result.trashedCount += 1
                    result.freedBytes += freed
                case .failed(let message):
                    result.errors.append(message)
                }
            }
        }

        let skipped = unique.count - prepared.count
        if skipped > 0 {
            let message = "Skipped \(skipped) item\(skipped == 1 ? "" : "s") without folder permission. Grant Applications or the related folders, then try again."
            result.errors.append(message)
            await MainActor.run {
                log.log(.error, message)
            }
        }

        return result
    }

    private enum RetryOutcome {
        case succeeded(Int64)
        case failed(String)
    }

    @MainActor
    private func retryTrash(url: URL, size: Int64, previousError: Error) -> RetryOutcome {
        guard let scoped = bookmarks.requestAccessForTrashing(
            url: url,
            itemName: url.lastPathComponent
        ) else {
            let message = Self.permissionAwareMessage(for: url, error: previousError)
            log.log(.error, message, path: url.path)
            return .failed(message)
        }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: scoped, resultingItemURL: &resultingURL)
            log.log(.clean, "Moved to Trash: \(scoped.lastPathComponent)", path: scoped.path)
            return .succeeded(size)
        } catch {
            let message = Self.permissionAwareMessage(for: scoped, error: error)
            log.log(.error, message, path: scoped.path)
            return .failed(message)
        }
    }

    /// Resolves security-scoped URLs, prompting for Applications access when needed.
    @MainActor
    private func prepareScopedURLs(for urls: [URL]) -> [URL] {
        let appPaths = urls.filter { $0.pathExtension == "app" }.map(\.path)
        if !appPaths.isEmpty {
            _ = bookmarks.ensureApplicationsAccess(forAppPaths: appPaths)
        }

        var scoped: [URL] = []
        var promptedParents = Set<String>()

        for url in urls {
            if let ready = bookmarks.scopedURLForTrashing(url) {
                scoped.append(ready)
                continue
            }

            let parent = url.deletingLastPathComponent().path
            // Avoid repeated panels for many leftovers under the same missing folder.
            if promptedParents.contains(parent), bookmarks.scopedURLForTrashing(url) == nil {
                continue
            }
            promptedParents.insert(parent)

            if let granted = bookmarks.requestAccessForTrashing(url: url, itemName: url.lastPathComponent) {
                scoped.append(granted)
                // After granting a parent folder, pick up any other pending URLs under it.
                for other in urls where !scoped.contains(other) {
                    if let extra = bookmarks.scopedURLForTrashing(other) {
                        scoped.append(extra)
                    }
                }
            }
        }

        // De-dupe while preserving order
        var seen = Set<URL>()
        return scoped.filter { seen.insert($0).inserted }
    }

    func isAllowed(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        let resolved = standardized.resolvingSymlinksInPath()
        
        // Critical path denylist - never allow trashing these
        let path = standardized.path
        let deniedPaths = [
            "/System",
            "/Library",
            "/Applications/Safari.app",
            "/Applications/Mail.app",
            "/Applications/Finder.app",
            BookmarkStore.realUserHomePath() + "/Pictures",
            BookmarkStore.realUserHomePath() + "/Music",
            BookmarkStore.realUserHomePath() + "/Movies",
            BookmarkStore.realUserHomePath() + "/Library/Keychains",
            BookmarkStore.realUserHomePath() + "/.ssh",
            BookmarkStore.realUserHomePath() + "/.aws",
        ]
        
        for denied in deniedPaths {
            if path == denied || path.hasPrefix(denied + "/") {
                return false
            }
        }
        
        // Check for sensitive file extensions
        let sensitiveExtensions = ["pem", "key", "p12", "pfx", "keychain"]
        if sensitiveExtensions.contains(standardized.pathExtension.lowercased()) {
            return false
        }

        if bookmarks.containsPath(standardized.path) || bookmarks.containsPath(resolved.path) {
            return true
        }

        if standardized.pathExtension == "app", isUserApplication(standardized) {
            return bookmarks.containsPath(standardized.path)
                || bookmarks.containsPath("/Applications")
                || bookmarks.containsPath(BookmarkStore.realUserHomePath() + "/Applications")
        }

        return false
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

    private static func permissionAwareMessage(for url: URL, error: Error) -> String {
        let nsError = error as NSError
        let base = error.localizedDescription
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteNoPermissionError || nsError.code == 513 {
            return "Permission denied for \(url.lastPathComponent). Grant access to the Applications folder (or this item) when prompted, then try again."
        }
        if base.localizedCaseInsensitiveContains("permission") {
            return "Permission denied for \(url.lastPathComponent). Grant the Applications folder when prompted, then retry."
        }
        return "Could not trash \(url.lastPathComponent): \(base)"
    }
}
