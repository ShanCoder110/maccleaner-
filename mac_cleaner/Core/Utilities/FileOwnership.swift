//
//  FileOwnership.swift
//  mac_cleaner
//
//  Utilities for checking file ownership and permissions.
//

import Foundation

nonisolated enum FileOwnership {
    /// Checks if a file or directory is owned by root/system.
    /// Root-owned files cannot be trashed by sandboxed Mac App Store apps.
    static func isOwnedByRoot(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let ownerName = attrs[.ownerAccountName] as? String else {
            return false
        }
        return ownerName == "root" || ownerName == "system"
    }
    
    /// Why this app cannot move a system-owned item to Trash. No Terminal/sudo instructions.
    static func rootOwnershipExplanation(for url: URL) -> String {
        "\(url.lastPathComponent) is owned by the system and can’t be moved to Trash from this app."
    }

    static func skippedRootOwnedStatus(names: String, more: String) -> String {
        "Skipped system-owned items: \(names)\(more). They can’t be moved to Trash from this app."
    }

    /// Short label for UI badges
    static let rootOwnedLabel = "System-owned"

    /// Short explanation for tooltips
    static let rootOwnedTooltip = "Owned by the system. This app can’t move it to Trash."
}
