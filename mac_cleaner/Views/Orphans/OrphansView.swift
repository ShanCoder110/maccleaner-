//
//  OrphansView.swift
//  mac_cleaner
//

import SwiftUI

struct OrphansView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub

    @State private var searchText = ""
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var statusMessage = ""
    @State private var isRescanning = false

    private var orphans: OrphansResultsStore { scanResults.orphans }

    private var itemsBinding: Binding<[LeftoverItem]> {
        Binding(
            get: { orphans.items },
            set: {
                orphans.items = $0
                appState.rebuildScanSummaries()
            }
        )
    }

    private var filtered: [LeftoverItem] {
        guard !searchText.isEmpty else { return orphans.items }
        return orphans.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.displayPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selected: [LeftoverItem] { orphans.items.filter(\.isSelected) }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Orphans",
                subtitle: session.hasResults
                    ? "Using Smart Scan results — rescan anytime"
                    : "Related files in granted folders with no matching installed app",
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
                    PrimaryButton(
                        title: "Trash Selected",
                        icon: "trash",
                        isLoading: isCleaning,
                        isDisabled: selected.isEmpty,
                        size: .compact
                    ) { confirmClean = true }
                }

                if isRescanning || session.isScanning {
                    ProgressView(session.isScanning ? "\(session.progressPercent)% · \(session.progressLabel)" : "Looking for orphaned files…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    EmptyState(
                        title: session.hasResults ? "No orphans found" : "No scan yet",
                        message: session.hasResults
                            ? "Smart Scan did not find orphaned files in authorized folders."
                            : "Run Smart Scan on the home page, or tap Scan here.",
                        systemImage: "tray",
                        primaryActionTitle: session.hasResults ? "Rescan" : "Scan",
                        primaryAction: rescan
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(itemsBinding) { $item in
                                if searchText.isEmpty
                                    || item.name.localizedCaseInsensitiveContains(searchText)
                                    || item.displayPath.localizedCaseInsensitiveContains(searchText) {
                                    SelectableAppCard(isSelected: item.isSelected) {
                                        item.isSelected.toggle()
                                    } content: {
                                        HStack(spacing: AppSpacing.md) {
                                            SelectionCheckbox(isSelected: $item.isSelected)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(AppTypography.bodyMedium)
                                                    .foregroundStyle(AppColors.textPrimary)
                                                Text(item.displayPath)
                                                    .font(AppTypography.caption)
                                                    .foregroundStyle(AppColors.textTertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            if item.isRootOwned {
                                                StatusBadge(title: "Root-owned", style: .danger)
                                                    .help(FileOwnership.rootOwnedTooltip)
                                            }
                                            StatusBadge(title: item.kind.title, style: item.kind.badgeStyle)
                                            SizeBadge(value: item.sizeLabel, emphasis: .prominent)
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

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(AppColors.background)
        .confirmationDialog("Move selected orphaned files to Trash?", isPresented: $confirmClean, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusLine: String {
        if session.isScanning || isRescanning { return "Scanning…" }
        if session.hasResults {
            return "Caches and logs are selected by default · \(orphans.items.count) items from Smart Scan"
        }
        return "Caches and logs are selected by default. Support files need a manual check."
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
        let selectedItems = selected
        let urls = selectedItems.map(\.url)
        
        // Check for root-owned files and warn user
        let rootOwnedItems = selectedItems.filter(\.isRootOwned)
        
        if !rootOwnedItems.isEmpty {
            let names = rootOwnedItems.prefix(3).map(\.name).joined(separator: ", ")
            let more = rootOwnedItems.count > 3 ? " and \(rootOwnedItems.count - 3) more" : ""
            statusMessage = "⚠️ Cannot delete root-owned files: \(names)\(more). These require manual deletion with sudo in Terminal. See Activity log for commands."
            
            // Log terminal commands for each root-owned file
            for item in rootOwnedItems {
                await MainActor.run {
                    appState.activityLog.log(.error, FileOwnership.rootOwnershipExplanation(for: item.url))
                }
            }
            isCleaning = false
            return
        }
        
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        appState.clearScanResultsAfterClean(removedURLs: removed)
        
        if !result.errors.isEmpty {
            statusMessage = "⚠️ Moved \(result.trashedCount) items. \(result.errors.count) error(s) - see Activity log."
        } else {
            statusMessage = "✓ Moved \(result.trashedCount) items (\(ByteFormat.string(from: result.freedBytes)))."
        }
        isCleaning = false
    }
}
