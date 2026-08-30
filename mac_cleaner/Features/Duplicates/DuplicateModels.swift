//
//  DuplicateModels.swift
//  mac_cleaner
//
//  Duplicate confidence, keep recommendations, and group selection helpers.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Enums

enum DuplicateConfidence: String, Hashable, Sendable {
    case confirmed
    case possible

    var title: String {
        switch self {
        case .confirmed: return "Identical"
        case .possible: return "Possible"
        }
    }

    var badgeStyle: StatusBadgeStyle {
        switch self {
        case .confirmed: return .success
        case .possible: return .warning
        }
    }
}

enum DuplicateHashState: String, Hashable, Sendable {
    case fullVerified
    case partialOnly
    case unverified

    var title: String {
        switch self {
        case .fullVerified: return "Fully verified"
        case .partialOnly: return "Partial match only"
        case .unverified: return "Not verified"
        }
    }
}

enum DuplicateKeepRecommendation: Hashable, Sendable {
    case recommended
    case noClearRecommendation

    var title: String {
        switch self {
        case .recommended: return "Recommended to keep"
        case .noClearRecommendation: return "Choose which copy to keep"
        }
    }
}

enum DuplicateKeepReason: String, Hashable, Sendable {
    case userDataLocation
    case preferredLocation
    case recentlyModified
    case stableFilename
    case noClearPreference

    var explanation: String {
        switch self {
        case .userDataLocation:
            return "Located in a normal user folder."
        case .preferredLocation:
            return "Located in a preferred folder."
        case .recentlyModified:
            return "Recently modified."
        case .stableFilename:
            return "Has a stable filename."
        case .noClearPreference:
            return "No clear preference — choose the copy you want to keep."
        }
    }
}

enum DuplicateFileKind: String, Hashable, CaseIterable, Sendable {
    case image
    case video
    case document
    case archive
    case other

    var title: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .document: return "Document"
        case .archive: return "Archive"
        case .other: return "File"
        }
    }

    static func classify(url: URL) -> DuplicateFileKind {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "raw", "cr2", "nef"].contains(ext) {
            return .image
        }
        if ["mp4", "mov", "m4v", "avi", "mkv", "mpg", "mpeg", "wmv"].contains(ext) {
            return .video
        }
        if ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key", "md"].contains(ext) {
            return .document
        }
        if ["zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg"].contains(ext) {
            return .archive
        }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .text) || type.conforms(to: .pdf) { return .document }
            if type.conforms(to: .archive) { return .archive }
        }
        return .other
    }
}

enum DuplicateGroupSort: String, CaseIterable, Identifiable, Hashable {
    case recoverableSize
    case totalSize
    case copyCount
    case fileName

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recoverableSize: return "Recoverable"
        case .totalSize: return "Total size"
        case .copyCount: return "Copies"
        case .fileName: return "Name"
        }
    }
}

enum DuplicateGroupFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case large
    case manyCopies
    case images
    case videos
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .large: return "Large"
        case .manyCopies: return "Many copies"
        case .images: return "Images"
        case .videos: return "Videos"
        case .documents: return "Documents"
        }
    }

    /// Large = recoverable selection or theoretical reclaim ≥ 50 MB.
    static let largeThresholdBytes: Int64 = 50 * 1024 * 1024
}

// MARK: - File

struct DuplicateFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let parentFolder: String
    var byteSize: Int64
    var modified: Date?
    var created: Date?
    var fileKind: DuplicateFileKind
    var hashState: DuplicateHashState
    var isSelected: Bool
    var isRecommendedKeep: Bool
    var keepReason: DuplicateKeepReason?

    var sizeLabel: String { ByteFormat.string(from: byteSize) }
    var path: String { url.path }
    var folderLabel: String { parentFolder }

    var modifiedLabel: String {
        guard let modified else { return "Unknown" }
        return DuplicateDateFormat.string(from: modified)
    }

    init(
        id: UUID = UUID(),
        url: URL,
        byteSize: Int64,
        modified: Date?,
        created: Date?,
        hashState: DuplicateHashState,
        isSelected: Bool = false,
        isRecommendedKeep: Bool = false,
        keepReason: DuplicateKeepReason? = nil
    ) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.parentFolder = url.deletingLastPathComponent().path
        self.byteSize = byteSize
        self.modified = modified
        self.created = created
        self.fileKind = DuplicateFileKind.classify(url: url)
        self.hashState = hashState
        self.isSelected = isSelected
        self.isRecommendedKeep = isRecommendedKeep
        self.keepReason = keepReason
    }
}

// MARK: - Group

struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Per-file size (identical for exact duplicates).
    let byteSize: Int64
    var files: [DuplicateFile]
    var keepID: UUID?
    var confidence: DuplicateConfidence
    var keepRecommendation: DuplicateKeepRecommendation

    var sizeLabel: String { ByteFormat.string(from: byteSize) }

    var totalSize: Int64 { byteSize * Int64(files.count) }

    var totalSizeLabel: String { ByteFormat.string(from: totalSize) }

    /// Bytes currently selected for removal.
    var selectedBytes: Int64 {
        files.filter(\.isSelected).reduce(0) { $0 + $1.byteSize }
    }

    /// Prefer selected reclaim; fall back to theoretical (keep one) for confirmed groups.
    var recoverableBytes: Int64 { selectedBytes }

    var theoreticalRecoverableBytes: Int64 {
        byteSize * Int64(max(0, files.count - 1))
    }

    var reclaimableLabel: String {
        ByteFormat.string(from: recoverableBytes)
    }

    var displayName: String {
        files.first?.name ?? "Duplicate files"
    }

    var hasClearKeepRecommendation: Bool {
        keepRecommendation == .recommended && keepID != nil
    }

    var wouldDeleteAllIfCurrentSelection: Bool {
        !files.isEmpty && files.allSatisfy(\.isSelected)
    }

    init(
        id: UUID = UUID(),
        byteSize: Int64,
        files: [DuplicateFile],
        confidence: DuplicateConfidence,
        keepRecommendation: DuplicateKeepRecommendation = .noClearRecommendation,
        keepID: UUID? = nil
    ) {
        self.id = id
        self.byteSize = byteSize
        self.files = files
        self.confidence = confidence
        self.keepRecommendation = keepRecommendation
        self.keepID = keepID
        normalizeAfterMutation()
    }

    mutating func setKeep(fileID: UUID) {
        guard files.contains(where: { $0.id == fileID }) else { return }
        keepID = fileID
        keepRecommendation = .recommended
        for i in files.indices {
            let isKeep = files[i].id == fileID
            files[i].isRecommendedKeep = isKeep
            files[i].isSelected = !isKeep
            if isKeep {
                files[i].keepReason = files[i].keepReason ?? .preferredLocation
            } else {
                files[i].keepReason = nil
            }
        }
    }

    mutating func selectAllExceptKeep() {
        guard let keepID, hasClearKeepRecommendation else { return }
        for i in files.indices {
            files[i].isSelected = files[i].id != keepID
        }
        enforceAtLeastOneKept()
    }

    mutating func deselectAll() {
        for i in files.indices {
            files[i].isSelected = false
        }
    }

    mutating func selectEntireGroupForRemoval() {
        guard let keepID, hasClearKeepRecommendation else { return }
        selectAllExceptKeep()
        _ = keepID
    }

    mutating func setFileSelected(fileID: UUID, selected: Bool) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }

        if selected {
            // Selecting the current keep copy means the user wants a different keep.
            if files[index].id == keepID, hasClearKeepRecommendation {
                if let other = files.first(where: { $0.id != fileID && !$0.isSelected })
                    ?? files.first(where: { $0.id != fileID }) {
                    setKeep(fileID: other.id)
                    if let idx = files.firstIndex(where: { $0.id == fileID }) {
                        files[idx].isSelected = true
                    }
                    enforceAtLeastOneKept()
                    return
                }
            }
            files[index].isSelected = true
        } else {
            files[index].isSelected = false
        }
        enforceAtLeastOneKept()
    }

    mutating func normalizeAfterMutation() {
        enforceAtLeastOneKept()
        if let keepID, let idx = files.firstIndex(where: { $0.id == keepID }) {
            files[idx].isSelected = false
            files[idx].isRecommendedKeep = true
        }
    }

    /// Never allow every copy in a group to be selected for Trash.
    private mutating func enforceAtLeastOneKept() {
        guard !files.isEmpty else { return }
        if files.allSatisfy(\.isSelected) {
            if let keepID, let idx = files.firstIndex(where: { $0.id == keepID }) {
                files[idx].isSelected = false
            } else if let idx = files.indices.first {
                files[idx].isSelected = false
                self.keepID = files[idx].id
            }
        }
    }
}

struct DuplicateScanResult: Hashable, Sendable {
    var groups: [DuplicateGroup]
    var hitEntryLimit: Bool
    var hitGroupLimit: Bool
    var entryLimit: Int
    var groupLimit: Int

    var warnings: [String] {
        DuplicateScanLimits.warnings(
            hitEntryLimit: hitEntryLimit,
            hitGroupLimit: hitGroupLimit,
            entryLimit: entryLimit,
            groupLimit: groupLimit
        )
    }
}

enum DuplicateScanLimits: Sendable {
    static func warnings(
        hitEntryLimit: Bool,
        hitGroupLimit: Bool,
        entryLimit: Int,
        groupLimit: Int
    ) -> [String] {
        var list: [String] = []
        if hitEntryLimit {
            list.append(
                "A folder had more than \(entryLimit.formatted()) files. Remaining files were skipped — authorize a smaller folder for a complete scan."
            )
        }
        if hitGroupLimit {
            list.append(
                "Showing the \(groupLimit.formatted()) largest duplicate groups. Authorize a smaller folder to see more."
            )
        }
        return list
    }
}

// MARK: - Keep scoring

enum DuplicateKeepScorer: Sendable {
    /// Score margin required to claim a clear recommendation.
    static let clearMargin: Int = 8

    static func applyRecommendation(to files: [DuplicateFile]) -> (
        files: [DuplicateFile],
        keepID: UUID?,
        recommendation: DuplicateKeepRecommendation,
        primaryReason: DuplicateKeepReason
    ) {
        guard !files.isEmpty else {
            return ([], nil, .noClearRecommendation, .noClearPreference)
        }
        if files.count == 1 {
            var only = files[0]
            only.isRecommendedKeep = true
            only.isSelected = false
            only.keepReason = .noClearPreference
            return ([only], only.id, .noClearRecommendation, .noClearPreference)
        }

        let scored = files.map { (file: $0, score: score($0), reasons: reasons(for: $0)) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lm = lhs.file.modified ?? .distantPast
                let rm = rhs.file.modified ?? .distantPast
                if lm != rm { return lm > rm }
                return lhs.file.path < rhs.file.path
            }

        let best = scored[0]
        let second = scored[1]
        let clear = best.score - second.score >= clearMargin

        var updated = files
        let keepID = best.file.id
        let primaryReason = best.reasons.first ?? .noClearPreference

        for i in updated.indices {
            let isKeep = updated[i].id == keepID
            updated[i].isRecommendedKeep = isKeep && clear
            updated[i].keepReason = isKeep ? (clear ? primaryReason : .noClearPreference) : nil
            if clear {
                updated[i].isSelected = !isKeep
            } else {
                updated[i].isSelected = false
                updated[i].isRecommendedKeep = false
            }
        }

        if clear {
            return (updated, keepID, .recommended, primaryReason)
        }
        return (updated, nil, .noClearRecommendation, .noClearPreference)
    }

    static func score(_ file: DuplicateFile) -> Int {
        var total = 0
        let path = file.path.lowercased()
        let home = BookmarkStore.realUserHomePath().lowercased()

        if path.contains("/.trash") || path.hasSuffix("/trash") || path.contains("/trash/") {
            total -= 80
        }
        if path.contains("/library/caches") || path.contains("/tmp/") || path.contains("/temporaryitems")
            || path.contains("/var/folders") {
            total -= 40
        }
        if path.contains("/downloads") { total += 5 }
        if path.contains("/documents") { total += 28 }
        if path.contains("/desktop") { total += 18 }
        if path.contains("/pictures") || path.contains("/movies") || path.contains("/music") {
            total += 22
        }
        if path.hasPrefix(home) { total += 10 }

        let name = file.name.lowercased()
        if name.contains(" copy") || name.contains("-copy") || name.hasPrefix("copy of")
            || name.range(of: #"\(\d+\)\."#, options: .regularExpression) != nil {
            total -= 12
        }
        if name.contains("export") || name.contains("temp") || name.contains("tmp") {
            total -= 8
        }

        if let modified = file.modified {
            let days = Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 999
            if days <= 30 { total += 14 }
            else if days <= 180 { total += 6 }
        }

        return total
    }

    static func reasons(for file: DuplicateFile) -> [DuplicateKeepReason] {
        var list: [DuplicateKeepReason] = []
        let path = file.path.lowercased()
        if path.contains("/documents") || path.contains("/pictures") || path.contains("/movies")
            || path.contains("/music") || path.contains("/desktop") {
            list.append(.userDataLocation)
        } else if !path.contains("/library/caches") && !path.contains("/tmp/") {
            list.append(.preferredLocation)
        }
        if let modified = file.modified {
            let days = Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 999
            if days <= 30 { list.append(.recentlyModified) }
        }
        let name = file.name.lowercased()
        if !(name.contains(" copy") || name.contains("export") || name.contains("temp")) {
            list.append(.stableFilename)
        }
        if list.isEmpty { list.append(.noClearPreference) }
        return list
    }

    static func combinedExplanation(reasons: [DuplicateKeepReason]) -> String {
        let unique = reasons.filter { $0 != .noClearPreference }
        guard !unique.isEmpty else { return DuplicateKeepReason.noClearPreference.explanation }
        if unique.count == 1 { return unique[0].explanation }
        if unique.contains(.userDataLocation), unique.contains(.recentlyModified) {
            return "Located in a normal user folder and recently modified."
        }
        if unique.contains(.preferredLocation), unique.contains(.recentlyModified) {
            return "Recently modified and in a preferred location."
        }
        return unique.prefix(2).map(\.explanation).joined(separator: " ")
    }
}

enum DuplicateDateFormat {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

enum DuplicateListHelpers {
    static func filtered(
        _ groups: [DuplicateGroup],
        filter: DuplicateGroupFilter,
        search: String
    ) -> [DuplicateGroup] {
        groups.filter { group in
            matchesFilter(group, filter: filter) && matchesSearch(group, search: search)
        }
    }

    static func sorted(_ groups: [DuplicateGroup], by sort: DuplicateGroupSort) -> [DuplicateGroup] {
        switch sort {
        case .recoverableSize:
            return groups.sorted {
                if $0.theoreticalRecoverableBytes != $1.theoreticalRecoverableBytes {
                    return $0.theoreticalRecoverableBytes > $1.theoreticalRecoverableBytes
                }
                return $0.totalSize > $1.totalSize
            }
        case .totalSize:
            return groups.sorted { $0.totalSize > $1.totalSize }
        case .copyCount:
            return groups.sorted { $0.files.count > $1.files.count }
        case .fileName:
            return groups.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private static func matchesFilter(_ group: DuplicateGroup, filter: DuplicateGroupFilter) -> Bool {
        switch filter {
        case .all: return true
        case .large:
            return group.theoreticalRecoverableBytes >= DuplicateGroupFilter.largeThresholdBytes
        case .manyCopies:
            return group.files.count >= 3
        case .images:
            return group.files.contains { $0.fileKind == .image }
        case .videos:
            return group.files.contains { $0.fileKind == .video }
        case .documents:
            return group.files.contains { $0.fileKind == .document }
        }
    }

    private static func matchesSearch(_ group: DuplicateGroup, search: String) -> Bool {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return group.files.contains { file in
            file.name.localizedCaseInsensitiveContains(q)
                || file.path.localizedCaseInsensitiveContains(q)
                || file.url.pathExtension.localizedCaseInsensitiveContains(q)
                || file.fileKind.title.localizedCaseInsensitiveContains(q)
        }
    }
}
