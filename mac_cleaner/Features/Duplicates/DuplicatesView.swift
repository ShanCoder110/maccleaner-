//
//  DuplicatesView.swift
//  mac_cleaner
//
//  Safe duplicate review: confirm identical files, choose what to keep, Trash only.
//

import SwiftUI
import AppKit

struct DuplicatesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub
    @EnvironmentObject private var bookmarks: BookmarkStore

    @State private var searchText = ""
    @State private var filter: DuplicateGroupFilter = .all
    @State private var sort: DuplicateGroupSort = .recoverableSize
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var isRescanning = false
    @State private var whyGroupID: UUID?
    @State private var cleanSummary: DuplicateCleanSummary?
    @State private var expandedDetailsID: UUID?

    private var duplicates: DuplicatesResultsStore { scanResults.duplicates }

    private var groupsBinding: Binding<[DuplicateGroup]> {
        Binding(
            get: { duplicates.groups },
            set: {
                duplicates.groups = $0
                appState.rebuildScanSummaries()
            }
        )
    }

    private var displayedGroups: [DuplicateGroup] {
        let filtered = DuplicateListHelpers.filtered(
            duplicates.groups,
            filter: filter,
            search: searchText
        )
        return DuplicateListHelpers.sorted(filtered, by: sort)
    }

    private var selectedURLs: [URL] {
        duplicates.groups.flatMap { $0.files.filter(\.isSelected).map(\.url) }
    }

    private var selectedBytes: Int64 {
        duplicates.groups.reduce(0) { $0 + $1.selectedBytes }
    }

    private var selectedFileCount: Int {
        duplicates.groups.flatMap(\.files).filter(\.isSelected).count
    }

    private var groupsWithAmbiguousKeep: Int {
        duplicates.groups.filter {
            $0.files.contains(where: \.isSelected) && !$0.hasClearKeepRecommendation
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Duplicates",
                subtitle: session.hasResults
                    ? "Identical files in folders you authorize — choose what to keep"
                    : "Find identical files, understand what you can recover, and choose which copy to keep",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()
                coverageCard
                controlsRow

                if !duplicates.limitMessages.isEmpty, session.hasResults {
                    limitBanner
                } else if !session.scannerWarnings.isEmpty, session.hasResults {
                    warningsBanner
                }

                if isRescanning || session.isScanning {
                    ProgressView(
                        session.isScanning
                            ? "\(session.progressPercent)% · \(session.progressLabel)"
                            : "Comparing file sizes and verifying content…"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !session.hasResults {
                    EmptyState(
                        title: "Find identical files",
                        message: bookmarks.hasAnyAccess
                            ? "Scan authorized folders for exact duplicates. You’ll review each group before anything moves to Trash."
                            : "Grant folder access to find duplicate files. MacCleaner+ only scans folders you authorize.",
                        systemImage: "rectangle.on.rectangle",
                        primaryActionTitle: bookmarks.hasAnyAccess ? "Scan for Duplicates" : "Manage Permissions",
                        primaryAction: {
                            if bookmarks.hasAnyAccess {
                                rescan()
                            } else {
                                appState.openManagePermissions()
                            }
                        },
                        secondaryActionTitle: bookmarks.hasAnyAccess ? "Manage Permissions" : nil,
                        secondaryAction: bookmarks.hasAnyAccess ? { appState.openManagePermissions() } : nil
                    )
                } else if duplicates.groups.isEmpty {
                    EmptyState(
                        title: "No duplicates found",
                        message: bookmarks.hasAnyAccess
                            ? "No identical files were found in your authorized folders."
                            : "No folders are available to scan. Grant folders to find duplicates.",
                        systemImage: "rectangle.on.rectangle",
                        primaryActionTitle: bookmarks.hasAnyAccess ? "Scan Again" : "Manage Permissions",
                        primaryAction: {
                            if bookmarks.hasAnyAccess {
                                rescan()
                            } else {
                                appState.openManagePermissions()
                            }
                        }
                    )
                } else if displayedGroups.isEmpty {
                    EmptyState(
                        title: "No matching groups",
                        message: "Try another filter or clear the search.",
                        systemImage: "line.3.horizontal.decrease.circle",
                        primaryActionTitle: "Clear Filters",
                        primaryAction: {
                            filter = .all
                            searchText = ""
                        }
                    )
                } else {
                    resultsHeader
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(displayedGroups) { group in
                                if let index = duplicates.groups.firstIndex(where: { $0.id == group.id }) {
                                    groupCard(groupsBinding[index])
                                }
                            }
                        }
                    }

                    bottomBar
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(Color.clear)
        .confirmationDialog(
            "Move selected duplicates to Trash?",
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .sheet(item: $cleanSummary) { summary in
            cleanResultSheet(summary)
        }
        .sheet(item: Binding(
            get: { whyGroupID.map { WhyKeepSheetID(id: $0) } },
            set: { whyGroupID = $0?.id }
        )) { item in
            if let group = duplicates.groups.first(where: { $0.id == item.id }) {
                whyKeepSheet(group)
            }
        }
    }

    // MARK: - Coverage

    private var coverageCard: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanned locations")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)
                    if session.coverageTitles.isEmpty {
                        Text("No authorized folders yet")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        Text(session.coverageTitles.joined(separator: " · "))
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)
                        Text("\(session.coverageTitles.count) authorized folder\(session.coverageTitles.count == 1 ? "" : "s")")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                Spacer()
                SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                    appState.openManagePermissions()
                }
            }
        }
    }

    private var limitBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan limit reached")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textPrimary)
                ForEach(duplicates.limitMessages, id: \.self) { message in
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.accentMuted)
        )
    }

    private var warningsBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColors.accent)
            Text(session.scannerWarnings.joined(separator: " "))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.accentMuted)
        )
    }

    private var controlsRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                AppFilterChipGroup(
                    options: DuplicateGroupFilter.allCases.map { ($0, $0.title) },
                    selection: $filter
                )
                Spacer(minLength: 0)
                AppMenuPicker(
                    label: "Sort",
                    options: DuplicateGroupSort.allCases.map { ($0, $0.title) },
                    selection: $sort,
                    minWidth: 120
                )
                if session.isScanning {
                    SecondaryButton(title: "Cancel", icon: "xmark", size: .compact) {
                        appState.cancelSmartScan()
                    }
                } else {
                    SecondaryButton(
                        title: session.hasResults ? "Rescan" : "Scan",
                        icon: "magnifyingglass",
                        size: .compact,
                        action: rescan
                    )
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(ByteFormat.string(from: selectedBytes)) recoverable")
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(duplicates.groups.count) duplicate group\(duplicates.groups.count == 1 ? "" : "s") · \(selectedFileCount) selected")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            StatusBadge(title: "Review recommended", style: .warning)
        }
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(ByteFormat.string(from: selectedBytes)) selected")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Moved to Trash only — nothing is permanently deleted.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            PrimaryButton(
                title: "Move Selected to Trash",
                icon: "trash",
                isLoading: isCleaning,
                isDisabled: selectedURLs.isEmpty || selectedWouldDeleteAll(),
                size: .compact
            ) { confirmClean = true }
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Group card

    private func groupCard(_ group: Binding<DuplicateGroup>) -> some View {
        let value = group.wrappedValue
        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(value.files.count) identical files")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(value.displayName)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        SizeBadge(
                            value: "Recoverable \(ByteFormat.string(from: value.selectedBytes))",
                            emphasis: .accent
                        )
                        Text("Total \(value.totalSizeLabel)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                HStack(spacing: AppSpacing.sm) {
                    StatusBadge(title: value.confidence.title, style: value.confidence.badgeStyle)
                    if value.confidence == .possible {
                        Text("Not fully verified — left unselected")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }

                if value.hasClearKeepRecommendation, let keep = value.files.first(where: { $0.id == value.keepID }) {
                    recommendedRow(group: group, file: keep)
                } else {
                    Text(DuplicateKeepReason.noClearPreference.explanation)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                ForEach(value.files.filter { $0.id != value.keepID || !value.hasClearKeepRecommendation }) { file in
                    fileRow(group: group, file: file, isKeep: file.id == value.keepID && value.hasClearKeepRecommendation)
                }

                HStack(spacing: AppSpacing.sm) {
                    if value.hasClearKeepRecommendation {
                        SecondaryButton(title: "Select duplicates", size: .compact) {
                            group.wrappedValue.selectAllExceptKeep()
                            appState.rebuildScanSummaries()
                        }
                    } else {
                        Text("Choose a copy to keep")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    SecondaryButton(title: "Deselect all", size: .compact) {
                        group.wrappedValue.deselectAll()
                        appState.rebuildScanSummaries()
                    }

                    Spacer()

                    SecondaryButton(title: "Details", size: .compact) {
                        expandedDetailsID = expandedDetailsID == value.id ? nil : value.id
                    }
                }

                if expandedDetailsID == value.id {
                    detailsBlock(value)
                }
            }
        }
    }

    private func recommendedRow(group: Binding<DuplicateGroup>, file: DuplicateFile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(AppColors.accent)
                Text("Recommended to keep")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Button("Why?") {
                    whyGroupID = group.wrappedValue.id
                }
                .buttonStyle(.plain)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.accent)
            }

            fileRow(group: group, file: file, isKeep: true)

            Text(DuplicateKeepScorer.combinedExplanation(reasons: DuplicateKeepScorer.reasons(for: file)))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.accentMuted.opacity(0.55))
        )
    }

    private func fileRow(group: Binding<DuplicateGroup>, file: DuplicateFile, isKeep: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            SelectionCheckbox(
                isSelected: Binding(
                    get: {
                        group.wrappedValue.files.first(where: { $0.id == file.id })?.isSelected ?? false
                    },
                    set: { newValue in
                        group.wrappedValue.setFileSelected(fileID: file.id, selected: newValue)
                        appState.rebuildScanSummaries()
                    }
                )
            )
            .disabled(isKeep && group.wrappedValue.hasClearKeepRecommendation)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.xs) {
                    Text(file.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    if isKeep {
                        StatusBadge(title: "Keep", style: .success)
                    }
                }
                Text(shortPath(file.parentFolder))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                HStack(spacing: AppSpacing.md) {
                    Text(file.sizeLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Modified \(file.modifiedLabel)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(file.fileKind.title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer(minLength: 0)

            if !isKeep {
                SecondaryButton(title: "Keep this", size: .compact) {
                    group.wrappedValue.setKeep(fileID: file.id)
                    appState.rebuildScanSummaries()
                }
            }

            IconButton(systemName: "eye", size: 28, iconSize: 11) {
                QuickLookPreview.shared.preview(url: file.url)
            }
            .help("Preview")

            IconButton(systemName: "folder", size: 28, iconSize: 11) {
                appState.cleaning.reveal(file.url)
            }
            .help("Reveal in Finder")
        }
    }

    private func detailsBlock(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Verification: \(group.confidence == .confirmed ? "Full content match" : "Partial match only")")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            ForEach(group.files) { file in
                Text("\(file.name) · \(file.hashState.title)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Confirm / result

    private var confirmMessage: String {
        var lines = [
            "\(selectedFileCount) file\(selectedFileCount == 1 ? "" : "s")",
            ByteFormat.string(from: selectedBytes),
            "",
            "The selected copies will be moved to Trash.",
            "One copy from each duplicate group will remain.",
            "Nothing will be permanently deleted."
        ]
        if groupsWithAmbiguousKeep > 0 {
            lines.append("")
            lines.append("\(groupsWithAmbiguousKeep) group\(groupsWithAmbiguousKeep == 1 ? "" : "s") had no automatic keep recommendation.")
        }
        return lines.joined(separator: "\n")
    }

    private func whyKeepSheet(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Why keep this copy?")
                .font(AppTypography.headline)
            if let keep = group.files.first(where: { $0.id == group.keepID }) {
                Text(keep.path)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                let reasons = DuplicateKeepScorer.reasons(for: keep)
                Text(DuplicateKeepScorer.combinedExplanation(reasons: reasons))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
            } else {
                Text(DuplicateKeepReason.noClearPreference.explanation)
            }
            Spacer()
            HStack {
                Spacer()
                PrimaryButton(title: "Done") { whyGroupID = nil }
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 420, height: 240)
    }

    private func cleanResultSheet(_ summary: DuplicateCleanSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(summary.title)
                .font(AppTypography.title2)
            Text("\(summary.freedLabel) moved to Trash")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.accent)

            Text("\(summary.fileCount) files · \(summary.groupsAffected) duplicate groups")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            Text("Remaining duplicate groups: \(summary.remainingGroups)")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            if !summary.failedLabel.isEmpty {
                Text(summary.failedLabel)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.warning)
            }

            Text("Files stay in Trash until you empty it in Finder.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)

            Spacer()

            HStack {
                SecondaryButton(title: "Show in Trash") {
                    showTrash()
                }
                Spacer()
                PrimaryButton(title: "Done") {
                    cleanSummary = nil
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 440, height: 300)
    }

    // MARK: - Actions

    private func shortPath(_ path: String) -> String {
        let home = BookmarkStore.realUserHomePath()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func selectedWouldDeleteAll() -> Bool {
        duplicates.groups.contains { group in
            group.files.contains(where: \.isSelected) && group.wouldDeleteAllIfCurrentSelection
        }
    }

    private func rescan() {
        isRescanning = true
        Task {
            await appState.runSmartScan()
            isRescanning = false
        }
    }

    private func clean() async {
        isCleaning = true
        let urls = selectedURLs
        let bytesSelected = selectedBytes
        let beforeGroups = duplicates.groups.count
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        appState.clearScanResultsAfterClean(removedURLs: removed)

        let failedBytes = max(0, bytesSelected - result.freedBytes)
        cleanSummary = DuplicateCleanSummary(
            title: result.errors.isEmpty ? "Duplicate cleanup complete" : "Cleanup finished with issues",
            freedLabel: ByteFormat.string(from: result.freedBytes),
            fileCount: result.trashedCount,
            groupsAffected: max(0, beforeGroups - duplicates.groups.count),
            remainingGroups: duplicates.groups.count,
            failedLabel: result.errors.isEmpty
                ? ""
                : "\(ByteFormat.string(from: failedBytes)) could not be moved. See Activity for details."
        )
        isCleaning = false
    }

    private func showTrash() {
        let home = BookmarkStore.realUserHomePath()
        let trash = URL(fileURLWithPath: home).appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}

// MARK: - Sheet IDs

private struct WhyKeepSheetID: Identifiable {
    let id: UUID
}

private struct DuplicateCleanSummary: Identifiable {
    let id = UUID()
    var title: String
    var freedLabel: String
    var fileCount: Int
    var groupsAffected: Int
    var remainingGroups: Int
    var failedLabel: String
}
