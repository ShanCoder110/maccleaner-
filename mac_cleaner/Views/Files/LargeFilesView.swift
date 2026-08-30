//
//  LargeFilesView.swift
//  mac_cleaner
//

import SwiftUI

struct LargeFilesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub

    @State private var searchText = ""
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var statusMessage = ""
    @State private var thresholdMB: Double = 50
    @State private var isRescanning = false

    private var largeFiles: LargeFilesResultsStore { scanResults.largeFiles }

    private var itemsBinding: Binding<[StorageItem]> {
        Binding(
            get: { largeFiles.items },
            set: {
                largeFiles.items = $0
                appState.rebuildScanSummaries()
            }
        )
    }

    private var filteredCount: Int {
        let items = largeFiles.items
        guard !searchText.isEmpty else { return items.count }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.path.localizedCaseInsensitiveContains(searchText)
        }.count
    }

    private var selected: [StorageItem] { largeFiles.items.filter(\.isSelected) }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Large Files",
                subtitle: session.hasResults
                    ? "Using Smart Scan results — rescan anytime"
                    : "Find large files inside folders you authorized",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()

                HStack {
                    SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }

                    Text("Minimum size")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Slider(value: $thresholdMB, in: 10...500, step: 10)
                        .frame(maxWidth: 220)
                    Text("\(Int(thresholdMB)) MB")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 56, alignment: .leading)

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
                        title: "Move to Trash",
                        icon: "trash",
                        isLoading: isCleaning,
                        isDisabled: selected.isEmpty,
                        size: .compact
                    ) { confirmClean = true }
                }

                if let message = largeFiles.incompleteMessage, session.hasResults || !largeFiles.items.isEmpty, !session.isScanning {
                    incompleteBanner(message)
                }

                SectionHeader(
                    title: "Results",
                    subtitle: (isRescanning || session.isScanning)
                        ? "Scanning…"
                        : "\(filteredCount) files · \(selected.count) selected"
                ) {
                    SizeBadge(
                        value: ByteFormat.string(from: selected.reduce(0) { $0 + $1.byteSize }),
                        emphasis: .accent
                    )
                }

                if isRescanning || session.isScanning {
                    ProgressView(session.isScanning ? "\(session.progressPercent)% · \(session.progressLabel)" : "Scanning authorized folders…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if largeFiles.items.isEmpty {
                    EmptyState(
                        title: session.hasResults ? "No large files found" : "No scan yet",
                        message: session.hasResults
                            ? "Nothing above the size threshold in authorized folders."
                            : "Run Smart Scan on the home page, or tap Scan here.",
                        systemImage: "doc.on.doc",
                        primaryActionTitle: session.hasResults ? "Rescan" : "Scan",
                        primaryAction: rescan
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(itemsBinding) { $item in
                                if searchText.isEmpty
                                    || item.name.localizedCaseInsensitiveContains(searchText)
                                    || item.path.localizedCaseInsensitiveContains(searchText) {
                                    SelectableAppCard(isSelected: item.isSelected) {
                                        item.isSelected.toggle()
                                    } content: {
                                        HStack(spacing: AppSpacing.md) {
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
        .confirmationDialog("Move selected files to Trash?", isPresented: $confirmClean, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func incompleteBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan incomplete")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.accentMuted)
        )
    }

    private func rescan() {
        isRescanning = true
        Task {
            let scope = ScanScope.snapshot(from: appState.bookmarks)
            let minimum = Int64(thresholdMB) * 1024 * 1024
            let result = await ScanTask.detached {
                LargeFilesScanner(minimumBytes: minimum).scan(roots: scope.roots)
            }
            largeFiles.apply(result)
            if session.lastScanDate == nil {
                session.lastScanDate = Date()
            }
            appState.rebuildScanSummaries()
            isRescanning = false
            appState.activityLog.log(.scan, "Large files scan found \(result.items.count) items")
        }
    }

    private func clean() async {
        isCleaning = true
        let urls = selected.map(\.url)
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        appState.clearScanResultsAfterClean(removedURLs: removed)
        statusMessage = "Moved \(result.trashedCount) files (\(ByteFormat.string(from: result.freedBytes)))."
        isCleaning = false
    }
}
