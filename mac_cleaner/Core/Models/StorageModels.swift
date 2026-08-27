//
//  StorageModels.swift
//  mac_cleaner
//

import Foundation
import AppKit

struct GrantedFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var displayName: String
    var path: String
    var kind: Kind

    enum Kind: String, Codable, CaseIterable {
        case applicationSupport
        case caches
        case logs
        case preferences
        case containers
        case homeAI
        case custom
        case downloads
        case documents
        case desktop

        var title: String {
            switch self {
            case .applicationSupport: return "Application Support"
            case .caches: return "Caches"
            case .logs: return "Logs"
            case .preferences: return "Preferences"
            case .containers: return "Containers"
            case .homeAI: return "AI Tool Folders"
            case .custom: return "Custom Folder"
            case .downloads: return "Downloads"
            case .documents: return "Documents"
            case .desktop: return "Desktop"
            }
        }

        var systemImage: String {
            switch self {
            case .applicationSupport: return "folder"
            case .caches: return "externaldrive"
            case .logs: return "doc.text"
            case .preferences: return "gearshape"
            case .containers: return "shippingbox"
            case .homeAI: return "brain"
            case .custom: return "folder.badge.plus"
            case .downloads: return "arrow.down.circle"
            case .documents: return "doc"
            case .desktop: return "desktopcomputer"
            }
        }
    }
}

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleIdentifier + "|" + path.path }

    let name: String
    let bundleIdentifier: String
    let path: URL
    let version: String
    let isSystemApp: Bool
    var byteSize: Int64
    var isSelected: Bool = false
    var isExpanded: Bool = false

    var sizeLabel: String {
        ByteFormat.string(from: byteSize)
    }
}

enum LeftoverKind: String, Codable, CaseIterable {
    case appBundle
    case preferences
    case caches
    case applicationSupport
    case containers
    case logs
    case launchAgent
    case savedState
    case other

    var title: String {
        switch self {
        case .appBundle: return "App"
        case .preferences: return "Preferences"
        case .caches: return "Caches"
        case .applicationSupport: return "Support"
        case .containers: return "Container"
        case .logs: return "Logs"
        case .launchAgent: return "Launch Agent"
        case .savedState: return "Saved State"
        case .other: return "Related"
        }
    }

    var badgeStyle: StatusBadgeStyle {
        switch self {
        case .appBundle: return .info
        case .caches, .logs: return .success
        case .preferences, .applicationSupport, .containers: return .warning
        case .launchAgent, .savedState: return .neutral
        case .other: return .neutral
        }
    }
}

struct LeftoverItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let kind: LeftoverKind
    var byteSize: Int64
    var isSelected: Bool
    var isSensitive: Bool

    var displayPath: String { url.path }
    var name: String { url.lastPathComponent }
    var sizeLabel: String { ByteFormat.string(from: byteSize) }

    init(
        id: UUID = UUID(),
        url: URL,
        kind: LeftoverKind,
        byteSize: Int64,
        isSelected: Bool = true,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.byteSize = byteSize
        self.isSelected = isSensitive ? false : isSelected
        self.isSensitive = isSensitive
    }
}

struct StorageItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let category: String
    var byteSize: Int64
    var isSelected: Bool
    var isSensitive: Bool
    var modified: Date?

    var sizeLabel: String { ByteFormat.string(from: byteSize) }
    var path: String { url.path }

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        category: String,
        byteSize: Int64,
        isSelected: Bool = true,
        isSensitive: Bool = false,
        modified: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.category = category
        self.byteSize = byteSize
        self.isSelected = isSensitive ? false : isSelected
        self.isSensitive = isSensitive
        self.modified = modified
    }
}

struct DuplicateGroup: Identifiable, Hashable {
    let id: UUID
    let byteSize: Int64
    var files: [StorageItem]
    var keepID: UUID?

    var sizeLabel: String { ByteFormat.string(from: byteSize) }
    var reclaimableLabel: String {
        let reclaim = byteSize * Int64(max(0, files.count - 1))
        return ByteFormat.string(from: reclaim)
    }

    init(id: UUID = UUID(), byteSize: Int64, files: [StorageItem]) {
        self.id = id
        self.byteSize = byteSize
        self.files = files
        self.keepID = files.first?.id
    }
}

struct SpaceCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    var items: [StorageItem]
    var isExpanded: Bool = false

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.byteSize } }
    var sizeLabel: String { ByteFormat.string(from: totalBytes) }
    var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.byteSize } }
}

struct TreemapNode: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let byteSize: Int64
    var children: [TreemapNode]

    var sizeLabel: String { ByteFormat.string(from: byteSize) }

    init(id: UUID = UUID(), name: String, url: URL, byteSize: Int64, children: [TreemapNode] = []) {
        self.id = id
        self.name = name
        self.url = url
        self.byteSize = byteSize
        self.children = children
    }
}

struct SmartScanCategoryResult: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    var totalBytes: Int64
    var itemCount: Int
    var progress: Double
    var destination: AppDestination?

    var sizeLabel: String { ByteFormat.string(from: totalBytes) }
}

enum ActivityKind: String, Codable {
    case scan
    case clean
    case error
    case info
}

struct ActivityLogEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let kind: ActivityKind
    let message: String
    let path: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: ActivityKind,
        message: String,
        path: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.message = message
        self.path = path
    }
}

struct CleanResult: Hashable {
    var trashedCount: Int = 0
    var freedBytes: Int64 = 0
    var errors: [String] = []
}

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f
    }()

    static func string(from bytes: Int64) -> String {
        formatter.string(fromByteCount: max(0, bytes))
    }
}
