//
//  ScanCoverageCopy.swift
//  mac_cleaner
//
//  Turns scan-limit notes into calm, user-friendly guidance.
//

import Foundation

enum ScanCoverageCopy {
    /// Maps technical / older warning strings into friendly coverage notes.
    static func friendly(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if lower.contains("couldn’t be calculated")
            || lower.contains("couldn't be calculated")
            || lower.contains("scan incomplete") {
            return "Results highlight the largest items first so the scan stays quick on big folders."
        }
        if lower.contains("remaining files were skipped") {
            return text
                .replacingOccurrences(of: "Remaining files were skipped — authorize a smaller folder for a complete scan.", with: "Authorize a smaller folder if you want every file checked.")
                .replacingOccurrences(of: "Remaining files were skipped - authorize a smaller folder for a complete scan.", with: "Authorize a smaller folder if you want every file checked.")
        }
        if lower.contains("large files limited") {
            return "Authorize folders in Permissions to unlock Large Files and more categories."
        }
        if lower.hasPrefix("scan incomplete") {
            return text.replacingOccurrences(of: "Scan incomplete — ", with: "")
                .replacingOccurrences(of: "Scan incomplete - ", with: "")
        }
        return text
    }
}
