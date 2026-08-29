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
        case applicationsSystem
        case applicationsUser

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
            case .applicationsSystem: return "Applications"
            case .applicationsUser: return "User Applications"
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
            case .applicationsSystem, .applicationsUser: return "square.grid.2x2"
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
    /// Best-effort last opened / last content access date from filesystem metadata.
    var lastOpenedDate: Date?
    var isSelected: Bool = false
    var isExpanded: Bool = false

    var sizeLabel: String {
        ByteFormat.string(from: byteSize)
    }

    var locationLabel: String {
        path.deletingLastPathComponent().path
    }

    var lastOpenedLabel: String? {
        guard let lastOpenedDate else { return nil }
        return lastOpenedDate.formatted(date: .abbreviated, time: .omitted)
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
        case .appBundle: return "Application"
        case .preferences: return "Preferences"
        case .caches: return "Caches"
        case .applicationSupport: return "Application Support"
        case .containers: return "Containers"
        case .logs: return "Logs"
        case .launchAgent: return "Launch Agents"
        case .savedState: return "Saved State"
        case .other: return "Other"
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

    /// Display order in expanded leftover groups.
    static var displayOrder: [LeftoverKind] {
        [.appBundle, .applicationSupport, .caches, .preferences, .containers, .logs, .savedState, .launchAgent, .other]
    }
}

struct LeftoverItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let kind: LeftoverKind
    var byteSize: Int64
    var isSelected: Bool
    var isSensitive: Bool
    var matchConfidence: MatchConfidence
    var matchReason: MatchReason
    var safety: SafetyClassification
    var isSharedOrPossiblyShared: Bool
    var relatedInstalledAppNames: [String]

    var displayPath: String { url.path }
    var name: String { url.lastPathComponent }
    var sizeLabel: String { ByteFormat.string(from: byteSize) }

    var whyExplanation: String {
        matchReason.explanation(appName: relatedInstalledAppNames.first ?? "this app", isShared: isSharedOrPossiblyShared)
    }

    init(
        id: UUID = UUID(),
        url: URL,
        kind: LeftoverKind,
        byteSize: Int64,
        isSelected: Bool? = nil,
        isSensitive: Bool = false,
        matchConfidence: MatchConfidence = .likely,
        matchReason: MatchReason = .normalizedName,
        safety: SafetyClassification? = nil,
        isSharedOrPossiblyShared: Bool = false,
        relatedInstalledAppNames: [String] = []
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.byteSize = byteSize
        self.isSensitive = isSensitive
        self.matchConfidence = matchConfidence
        self.matchReason = matchReason
        let resolvedSafety = safety ?? SafetyClassification.classify(kind: kind, url: url)
        self.safety = isSensitive ? .sensitive : resolvedSafety
        self.isSharedOrPossiblyShared = isSharedOrPossiblyShared
        self.relatedInstalledAppNames = relatedInstalledAppNames

        if let isSelected {
            self.isSelected = (self.safety == .sensitive || isSharedOrPossiblyShared) ? false : isSelected
        } else {
            self.isSelected = LeftoverItem.defaultSelection(
                kind: kind,
                confidence: matchConfidence,
                safety: self.safety,
                isShared: isSharedOrPossiblyShared
            )
        }
    }

    static func defaultSelection(
        kind: LeftoverKind,
        confidence: MatchConfidence,
        safety: SafetyClassification,
        isShared: Bool
    ) -> Bool {
        if isShared { return false }
        if safety == .sensitive { return false }
        if confidence == .possible { return false }
        if kind == .appBundle { return true }
        // Auto-select only confirmed/likely + clearly regenerable data.
        if safety == .safeToRemove, confidence == .confirmed || confidence == .likely {
            return true
        }
        // Review-recommended: only the app bundle (handled above) is auto-selected.
        return false
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

    /// Bytes reclaimable if one copy is kept.
    var recoverableBytes: Int64 {
        byteSize * Int64(max(0, files.count - 1))
    }

    var reclaimableLabel: String {
        ByteFormat.string(from: recoverableBytes)
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
    var recoverableBytes: Int64
    var itemCount: Int
    var progress: Double
    var destination: AppDestination?
    var safety: SmartScanCategorySafety
    var explanation: String
    var statusDetail: String?

    var sizeLabel: String { ByteFormat.string(from: totalBytes) }
    var recoverableLabel: String { ByteFormat.string(from: recoverableBytes) }

    init(
        id: String,
        title: String,
        systemImage: String,
        totalBytes: Int64,
        recoverableBytes: Int64? = nil,
        itemCount: Int,
        progress: Double,
        destination: AppDestination?,
        safety: SmartScanCategorySafety = .review,
        explanation: String = "",
        statusDetail: String? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.totalBytes = totalBytes
        self.recoverableBytes = recoverableBytes ?? totalBytes
        self.itemCount = itemCount
        self.progress = progress
        self.destination = destination
        self.safety = safety
        self.explanation = explanation
        self.statusDetail = statusDetail
    }
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
