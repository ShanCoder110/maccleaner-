//
//  AppDestination.swift
//  mac_cleaner
//

import Foundation
import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case smartScan
    case applications
    case spaceCleaner
    case largeFiles
    case duplicates
    case spaceLens
    case orphans
    case activity
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .applications: return "Applications"
        case .spaceCleaner: return "Space Cleaner"
        case .largeFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        case .spaceLens: return "Space Lens"
        case .orphans: return "Orphans"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .smartScan: return "sparkles"
        case .applications: return "square.grid.2x2"
        case .spaceCleaner: return "internaldrive"
        case .largeFiles: return "doc.on.doc"
        case .duplicates: return "rectangle.on.rectangle"
        case .spaceLens: return "square.3.layers.3d"
        case .orphans: return "tray"
        case .activity: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        }
    }

    /// Primary navigation shown in the Clean group.
    static var cleanGroup: [AppDestination] {
        [.smartScan, .applications, .spaceCleaner, .largeFiles, .duplicates, .spaceLens, .orphans]
    }

    static var toolsGroup: [AppDestination] {
        [.activity, .settings]
    }

    /// Per-tool accent so screens don't all share the same blue.
    var tint: Color {
        switch self {
        case .smartScan, .settings: return AppColors.accent
        case .applications: return AppColors.toolPurple
        case .spaceCleaner: return AppColors.success
        case .largeFiles: return AppColors.warning
        case .duplicates: return AppColors.toolTeal
        case .spaceLens: return AppColors.toolIndigo
        case .orphans: return AppColors.toolRose
        case .activity: return AppColors.toolSlate
        }
    }

    /// Features that require an active Pro subscription.
    var requiresPro: Bool {
        switch self {
        case .spaceCleaner, .largeFiles, .spaceLens, .orphans:
            return true
        default:
            return false
        }
    }
}

nonisolated enum LeftoverSensitivity: String, CaseIterable, Identifiable, Codable, Sendable {
    case strict
    case enhanced
    case deep

    var id: String { rawValue }

    /// User-facing label (Conservative / Recommended / Include possible).
    var title: String {
        switch self {
        case .strict: return "Conservative"
        case .enhanced: return "Recommended"
        case .deep: return "Include possible"
        }
    }

    var detail: String {
        switch self {
        case .strict:
            return "Show only strongly associated files."
        case .enhanced:
            return "Show strong and likely matches. Recommended default."
        case .deep:
            return "Also show weaker heuristic matches. They stay unchecked."
        }
    }
}
