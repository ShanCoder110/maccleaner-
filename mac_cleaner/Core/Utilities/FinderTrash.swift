//
//  FinderTrash.swift
//  mac_cleaner
//
//  Guideline 2.4.5(i): never write ~/.Trash from this process.
//  NSWorkspace.recycle asks Finder to move items; reveal uses Finder Apple Events.
//

import AppKit
import Foundation

enum FinderTrash {
    /// Asks Finder to move `url` to the user’s Trash. Does not touch `~/.Trash`.
    static func recycle(_ url: URL) async throws {
        try await recycle(urls: [url])
    }

    static func recycle(urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle(urls) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Opens Trash in Finder without this app reading `~/.Trash`.
    static func revealInFinder() {
        var error: NSDictionary?
        let script = NSAppleScript(source: """
            tell application "Finder"
                open trash
                activate
            end tell
            """)
        _ = script?.executeAndReturnError(&error)
    }
}
