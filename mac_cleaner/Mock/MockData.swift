//
//  MockData.swift
//  mac_cleaner
//
//  Dummy content for UI prototyping only — no real system access.
//

import Foundation

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case smartScan
    case applications
    case junkFiles
    case largeFiles
    case duplicates
    case designSystem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .applications: return "Applications"
        case .junkFiles: return "Junk Files"
        case .largeFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        case .designSystem: return "Design System"
        }
    }

    var systemImage: String {
        switch self {
        case .smartScan: return "sparkles"
        case .applications: return "square.grid.2x2"
        case .junkFiles: return "internaldrive"
        case .largeFiles: return "doc.on.doc"
        case .duplicates: return "rectangle.on.rectangle"
        case .designSystem: return "paintpalette"
        }
    }

    var badge: String? {
        switch self {
        case .applications: return "12"
        case .junkFiles: return "2.1 GB"
        case .largeFiles: return "8"
        case .duplicates: return "24"
        default: return nil
        }
    }
}

struct MockAppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let sizeLabel: String
    let leftoverCount: Int
    let status: StatusBadgeStyle
    var isSelected: Bool = false
}

struct MockJunkCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let sizeLabel: String
    let itemCount: Int
    let systemImage: String
    var progress: Double
}

enum MockData {
    static let applications: [MockAppItem] = [
        MockAppItem(name: "Sketch", category: "Design", sizeLabel: "842 MB", leftoverCount: 18, status: .warning, isSelected: true),
        MockAppItem(name: "Slack", category: "Communication", sizeLabel: "512 MB", leftoverCount: 7, status: .info),
        MockAppItem(name: "Docker Desktop", category: "Developer", sizeLabel: "1.8 GB", leftoverCount: 32, status: .danger),
        MockAppItem(name: "Notion", category: "Productivity", sizeLabel: "286 MB", leftoverCount: 4, status: .success),
        MockAppItem(name: "Figma", category: "Design", sizeLabel: "390 MB", leftoverCount: 11, status: .warning),
        MockAppItem(name: "Spotify", category: "Media", sizeLabel: "248 MB", leftoverCount: 9, status: .info),
    ]

    static let junkCategories: [MockJunkCategory] = [
        MockJunkCategory(title: "System Cache", subtitle: "Temporary OS and app caches", sizeLabel: "1.24 GB", itemCount: 1482, systemImage: "internaldrive", progress: 0.72),
        MockJunkCategory(title: "User Logs", subtitle: "Diagnostic and crash reports", sizeLabel: "318 MB", itemCount: 96, systemImage: "doc.text", progress: 0.28),
        MockJunkCategory(title: "iOS Backups", subtitle: "Old device backups on disk", sizeLabel: "4.6 GB", itemCount: 3, systemImage: "iphone", progress: 0.91),
        MockJunkCategory(title: "Mail Downloads", subtitle: "Attachments saved by Mail", sizeLabel: "512 MB", itemCount: 214, systemImage: "envelope", progress: 0.41),
    ]

    static let reclaimableTotal = "6.8 GB"
    static let lastScanLabel = "Last scan · 2 hours ago"
}
