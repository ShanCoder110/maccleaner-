//
//  SpaceCleanerView.swift
//  mac_cleaner
//

import SwiftUI

struct SpaceCleanerView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var statusMessage = ""
    @State private var isRescanning = false

    private var session: ScanSessionStore { appState.scanSession }

    private var categoriesBinding: Binding<[SpaceCategory]> {
        Binding(
            get: { session.spaceCategories },
            set: {
                session.spaceCategories = $0
                session.rebuildSummaries()
            }
        )
    }

    private var selectedURLs: [URL] {
        session.spaceCategories.flatMap { $0.items.filter(\.isSelected).map(\.url) }
    }

    private var selectedBytes: Int64 {
        session.spaceCategories.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.byteSize }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Space Cleaner",
                subtitle: session.hasResults
                    ? "Using Smart Scan results — rescan anytime"
                    : "Caches, logs, and AI tool data in folders you authorized",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()

                HStack {
                    SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }
                    Spacer()
                    SecondaryButton(
                        title: session.hasResults ? "Rescan" : "Scan",
                        icon: "magnifyingglass",
                        size: .compact,
                        action: rescan
                    )
                    PrimaryButton(
                        title: "Clean Selected",
                        icon: "trash",
                        isLoading: isCleaning,
                        isDisabled: selectedURLs.isEmpty,
                        size: .compact
                    ) { confirmClean = true }
                }

                SectionHeader(
                    title: "Junk categories",
                    subtitle: "Sensitive items stay unchecked by default"
                ) {
                    SizeBadge(value: ByteFormat.string(from: selectedBytes), emphasis: .accent)
                }

                if isRescanning || session.isScanning {
                    ProgressView(session.isScanning ? "\(session.progressPercent)% · \(session.progressLabel)" : "Scanning authorized locations…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if session.spaceCategories.isEmpty {
                    EmptyState(
                        title: session.hasResults ? "No junk categories" : "No scan yet",
                        message: session.hasResults
                            ? "Nothing matched in authorized cache/log folders."
                            : "Run Smart Scan on the home page, or tap Scan here.",
                        systemImage: "internaldrive",
                        primaryActionTitle: session.hasResults ? "Rescan" : "Scan",
                        primaryAction: rescan
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(categoriesBinding) { $category in
                                categoryCard($category)
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
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func categoryCard(_ category: Binding<SpaceCategory>) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Button {
                    category.wrappedValue.isExpanded.toggle()
                } label: {
                    HStack {
                        Image(systemName: category.wrappedValue.systemImage)
                            .foregroundStyle(AppColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.wrappedValue.title)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(category.wrappedValue.subtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        SizeBadge(value: category.wrappedValue.sizeLabel, emphasis: .prominent)
                        Image(systemName: category.wrappedValue.isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                if category.wrappedValue.isExpanded {
                    ForEach(category.items) { $item in
                        if searchText.isEmpty
                            || item.name.localizedCaseInsensitiveContains(searchText)
                            || item.category.localizedCaseInsensitiveContains(searchText) {
                            HStack(spacing: AppSpacing.sm) {
                                SelectionCheckbox(isSelected: $item.isSelected)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(item.path)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if item.isSensitive {
                                    StatusBadge(title: "Review", style: .warning)
                                }
                                StatusBadge(title: item.category, style: .info)
                                SizeBadge(value: item.sizeLabel)
                                IconButton(systemName: "folder", size: 28, iconSize: 11) {
                                    appState.cleaning.reveal(item.url)
                                }
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
        statusMessage = "Moved \(result.trashedCount) items (\(ByteFormat.string(from: result.freedBytes)))."
        isCleaning = false
    }
}
