//
//  ApplicationStorageModels.swift
//  mac_cleaner
//
//  Confidence, safety, and storage summary types for the Applications module.
//

import Foundation

// MARK: - Match confidence (separate from deletion safety)

enum MatchConfidence: String, Codable, CaseIterable, Identifiable, Hashable {
    case confirmed
    case likely
    case possible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .likely: return "Likely"
        case .possible: return "Possible"
        }
    }

    var badgeStyle: StatusBadgeStyle {
        switch self {
        case .confirmed: return .success
        case .likely: return .info
        case .possible: return .neutral
        }
    }

    /// Internal matching tier that can produce this confidence at most.
    var minimumSensitivity: LeftoverSensitivity {
        switch self {
        case .confirmed: return .strict
        case .likely: return .enhanced
        case .possible: return .deep
        }
    }
}

enum MatchReason: String, Codable, CaseIterable, Identifiable, Hashable {
    case appBundleItself
    case bundleIdentifier
    case exactAppName
    case exactPathComponent
    case normalizedName
    case bundleLastComponents
    case versionSuffixStripped
    case vendorName

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .appBundleItself: return "Application bundle"
        case .bundleIdentifier: return "Bundle identifier match"
        case .exactAppName: return "Exact application name"
        case .exactPathComponent: return "Exact path component"
        case .normalizedName: return "Normalized name match"
        case .bundleLastComponents: return "Bundle ID components"
        case .versionSuffixStripped: return "Version suffix stripped"
        case .vendorName: return "Developer name match"
        }
    }

    func explanation(appName: String, isShared: Bool) -> String {
        let sharedNote = isShared
            ? " This location may also be used by other installed applications."
            : ""

        switch self {
        case .appBundleItself:
            return "Confirmed because this is the selected application’s .app bundle."
        case .bundleIdentifier:
            return "Confirmed because the filename matches \(appName)’s bundle identifier.\(sharedNote)"
        case .exactAppName:
            return "Likely because the folder or file name exactly matches “\(appName).”\(sharedNote)"
        case .exactPathComponent:
            return "Likely because the name exactly matches the application’s path component.\(sharedNote)"
        case .normalizedName:
            return "Likely because the name matches a normalized form of “\(appName).”\(sharedNote)"
        case .bundleLastComponents:
            return "Possible because the name matches the last components of the app’s bundle identifier.\(sharedNote)"
        case .versionSuffixStripped:
            return "Possible because the name matches “\(appName)” after removing a trailing version number.\(sharedNote)"
        case .vendorName:
            return "Possible because the folder matches the developer name and may be shared with other applications from the same vendor.\(sharedNote)"
        }
    }

    var defaultConfidence: MatchConfidence {
        switch self {
        case .appBundleItself, .bundleIdentifier:
            return .confirmed
        case .exactAppName, .exactPathComponent, .normalizedName:
            return .likely
        case .bundleLastComponents, .versionSuffixStripped, .vendorName:
            return .possible
        }
    }
}

enum SafetyClassification: String, Codable, CaseIterable, Identifiable, Hashable {
    case safeToRemove
    case reviewRecommended
    case sensitive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safeToRemove: return "Safe to remove"
        case .reviewRecommended: return "Review recommended"
        case .sensitive: return "Sensitive"
        }
    }

    var badgeStyle: StatusBadgeStyle {
        switch self {
        case .safeToRemove: return .success
        case .reviewRecommended: return .warning
        case .sensitive: return .danger
        }
    }

    var detail: String {
        switch self {
        case .safeToRemove:
            return "Temporary or regenerable data such as caches and non-critical logs."
        case .reviewRecommended:
            return "Preferences, support files, or state that may reset the application."
        case .sensitive:
            return "Credentials, keys, or important configuration — left unchecked by default."
        }
    }

    static func classify(kind: LeftoverKind, url: URL) -> SafetyClassification {
        if PathNormalization.isSensitivePath(url) { return .sensitive }
        switch kind {
        case .caches, .logs:
            return .safeToRemove
        case .appBundle:
            return .reviewRecommended
        case .preferences, .applicationSupport, .containers, .savedState, .launchAgent, .other:
            return .reviewRecommended
        }
    }
}

struct AppStorageSummary: Hashable, Codable {
    var appBundleSize: Int64
    var relatedStorageSize: Int64
    var totalDiscoveredSize: Int64
    var lastScanDate: Date?
    /// True when values come from a previous scan cache, not a live scan this session.
    var isCachedEstimate: Bool

    static func unscanned(appBundleSize: Int64) -> AppStorageSummary {
        AppStorageSummary(
            appBundleSize: appBundleSize,
            relatedStorageSize: 0,
            totalDiscoveredSize: appBundleSize,
            lastScanDate: nil,
            isCachedEstimate: false
        )
    }

    static func from(items: [LeftoverItem], appBundleSize: Int64, scannedAt: Date, cached: Bool) -> AppStorageSummary {
        let related = items.filter { $0.kind != .appBundle }.reduce(Int64(0)) { $0 + $1.byteSize }
        let bundleFromItems = items.first(where: { $0.kind == .appBundle })?.byteSize ?? appBundleSize
        return AppStorageSummary(
            appBundleSize: bundleFromItems,
            relatedStorageSize: related,
            totalDiscoveredSize: bundleFromItems + related,
            lastScanDate: scannedAt,
            isCachedEstimate: cached
        )
    }
}

enum AppListSort: String, CaseIterable, Identifiable {
    case name
    case largestTotal
    case largestApp
    case leastRecentlyOpened

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Name"
        case .largestTotal: return "Largest total"
        case .largestApp: return "Largest app"
        case .leastRecentlyOpened: return "Least recently opened"
        }
    }
}

enum AppListFilter: String, CaseIterable, Identifiable {
    case all
    case selected
    case large
    case unused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .selected: return "Selected"
        case .large: return "Large"
        case .unused: return "Unused"
        }
    }
}

enum UnusedThreshold: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .threeMonths: return 90 * 24 * 60 * 60
        case .sixMonths: return 180 * 24 * 60 * 60
        case .oneYear: return 365 * 24 * 60 * 60
        }
    }
}
