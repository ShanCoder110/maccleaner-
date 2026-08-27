//
//  AppDestination.swift
//  mac_cleaner
//

import Foundation

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

enum LeftoverSensitivity: String, CaseIterable, Identifiable, Codable {
    case strict
    case enhanced
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: return "Strict"
        case .enhanced: return "Enhanced"
        case .deep: return "Deep"
        }
    }
}
