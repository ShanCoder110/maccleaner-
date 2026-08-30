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
    
    /// Returns a user-friendly explanation for why a root-owned file cannot be deleted.
    static func rootOwnershipExplanation(for url: URL) -> String {
        "This file is owned by root/system and requires admin privileges to delete. Run in Terminal: sudo rm -rf \"\(url.path)\""
    }
    
    /// Short label for UI badges
    static let rootOwnedLabel = "Root-owned"
    
    /// Short explanation for tooltips
    static let rootOwnedTooltip = "Owned by system. Requires sudo to delete manually."
}
