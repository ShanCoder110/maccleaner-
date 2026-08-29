//
//  DuplicatesView.swift
//  mac_cleaner
//

import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var statusMessage = ""
    @State private var isRescanning = false

    private var session: ScanSessionStore { appState.scanSession }

    private var groupsBinding: Binding<[DuplicateGroup]> {
        Binding(
            get: { session.duplicateGroups },
            set: {
                session.duplicateGroups = $0
                session.rebuildSummaries()
            }
        )
    }

    private var selectedURLs: [URL] {
        session.duplicateGroups.flatMap { group in
            group.files.filter(\.isSelected).map(\.url)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Duplicates",
                subtitle: session.hasResults
                    ? "Using Smart Scan results — rescan anytime"
                    : "Find duplicate files in folders you authorized",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()

                HStack {
                    SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }
                    Text(statusLine)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    SecondaryButton(
                        title: session.hasResults ? "Rescan" : "Scan",
                        icon: "magnifyingglass",
                        size: .compact,
                        action: rescan
                    )
                    PrimaryButton(
                        title: "Trash Selected",
                        icon: "trash",
                        isLoading: isCleaning,
                        isDisabled: selectedURLs.isEmpty,
                        size: .compact
                    ) { confirmClean = true }
                }

                if isRescanning || session.isScanning {
                    ProgressView(session.isScanning ? "\(session.progressPercent)% · \(session.progressLabel)" : "Comparing file sizes and hashes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if session.duplicateGroups.isEmpty {
                    EmptyState(
                        title: session.hasResults ? "No duplicates found" : "No scan yet",
                        message: session.hasResults
                            ? "Smart Scan did not find duplicate groups in authorized folders."
                            : "Run Smart Scan on the home page, or tap Scan here.",
                        systemImage: "rectangle.on.rectangle",
                        primaryActionTitle: session.hasResults ? "Rescan" : "Scan",
                        primaryAction: rescan
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(groupsBinding) { $group in
                                duplicateGroupCard($group)
                            }
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(AppColors.background)
        .confirmationDialog("Move selected duplicate copies to Trash?", isPresented: $confirmClean, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusLine: String {
        if session.isScanning || isRescanning { return "Scanning…" }
        if session.hasResults {
            return "\(session.duplicateGroups.count) groups · from Smart Scan"
        }
        return "\(session.duplicateGroups.count) groups"
    }

    private func duplicateGroupCard(_ group: Binding<DuplicateGroup>) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("\(group.wrappedValue.files.count) copies")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    SizeBadge(value: "Reclaim \(group.wrappedValue.reclaimableLabel)", emphasis: .accent)
                }

                ForEach(group.files) { $file in
                    if searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText) || file.path.localizedCaseInsensitiveContains(searchText) {
                        HStack(spacing: AppSpacing.sm) {
                            SelectionCheckbox(isSelected: $file.isSelected)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(file.path)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            SizeBadge(value: file.sizeLabel)
                            IconButton(systemName: "folder", size: 28, iconSize: 11) {
                                appState.cleaning.reveal(file.url)
                            }
                        }
                    }
                }
            }
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
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        session.clearAfterClean(removedURLs: removed)
        statusMessage = "Moved \(result.trashedCount) duplicates (\(ByteFormat.string(from: result.freedBytes)))."
        isCleaning = false
    }
}
