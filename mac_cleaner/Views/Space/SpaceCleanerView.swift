//
//  SpaceCleanerView.swift
//  mac_cleaner
//

import SwiftUI

struct SpaceCleanerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub

    @State private var searchText = ""
    @State private var isCleaning = false
    @State private var confirmClean = false
    @State private var statusMessage = ""
    @State private var isRescanning = false
    @State private var showingJunkDetail = false
    @State private var includedSources: Set<SpaceCleanupSource> = Set(SpaceCleanupSource.allCases)

    private var space: SpaceResultsStore { scanResults.space }

    private var categoriesBinding: Binding<[SpaceCategory]> {
        Binding(
            get: { space.categories },
            set: {
                space.categories = $0
                appState.rebuildScanSummaries()
            }
        )
    }

    private var hubRows: [SpaceCleanupRow] {
        SpaceCleanupSource.allCases.map { source in
            SpaceCleanupRow(source: source, snapshot: snapshot(for: source))
        }
        .filter { row in
            row.snapshot.itemCount > 0
                && (searchText.isEmpty
                    || row.source.title.localizedCaseInsensitiveContains(searchText)
                    || row.source.subtitle.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var selectedURLs: [URL] {
        uniqueURLs(hubRows.flatMap { row in
            guard includedSources.contains(row.source) else { return [URL]() }
            return row.snapshot.urls
        })
    }

    private var selectedBytes: Int64 {
        hubRows.reduce(0) { total, row in
            guard includedSources.contains(row.source) else { return total }
            return total + row.snapshot.bytes
        }
    }

    private var selectedItemCount: Int {
        hubRows.reduce(0) { total, row in
            guard includedSources.contains(row.source) else { return total }
            return total + row.snapshot.selectedCount
        }
    }

    private var recoverableTotal: Int64 {
        max(hubRows.reduce(0) { $0 + $1.snapshot.bytes }, selectedBytes, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Space Cleaner",
                subtitle: session.hasResults
                    ? "Using Smart Scan results — rescan anytime"
                    : "Named Apple, developer, and AI data in folders you authorized",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()
                toolbarRow

                if isRescanning || session.isScanning {
                    ProgressView(session.isScanning ? "\(session.progressPercent)% · \(session.progressLabel)" : "Scanning authorized locations…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !session.hasResults && space.categories.isEmpty && scanResults.largeFiles.items.isEmpty {
                    EmptyState(
                        title: "No scan yet",
                        message: "Run Smart Scan on the home page, or tap Scan here.",
                        systemImage: "internaldrive",
                        primaryActionTitle: "Scan",
                        primaryAction: rescan
                    )
                } else if showingJunkDetail {
                    junkDetailList
                } else if hubRows.isEmpty {
                    EmptyState(
                        title: "Nothing selected to clean",
                        message: "Scan again, or open a category to choose items.",
                        systemImage: "internaldrive",
                        primaryActionTitle: "Rescan",
                        primaryAction: rescan
                    )
                } else {
                    hubLayout
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(Color.clear)
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { Task { await clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(ByteFormat.string(from: selectedBytes))\n\(selectedItemCount) items\n\nSelected items will be moved to Trash. Nothing is permanently deleted.")
        }
    }

    private var toolbarRow: some View {
        HStack {
            if showingJunkDetail {
                SecondaryButton(title: "Overview", icon: "chevron.left", size: .compact) {
                    showingJunkDetail = false
                }
            }
            SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                appState.openManagePermissions()
            }
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
                title: "Clean Selected",
                icon: "trash",
                isLoading: isCleaning,
                isDisabled: selectedURLs.isEmpty,
                size: .compact
            ) { confirmClean = true }
        }
    }

    private var hubLayout: some View {
        HStack(alignment: .top, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeader(
                    title: "Selected for Cleanup",
                    subtitle: "Review a category, or clean everything that’s checked"
                )

                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(hubRows) { row in
                            hubCard(row)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            SpaceCleanerSummaryRail(
                rows: hubRows.filter { includedSources.contains($0.source) },
                selectedBytes: selectedBytes,
                recoverableTotal: recoverableTotal,
                isCleaning: isCleaning,
                isDisabled: selectedURLs.isEmpty,
                onClean: { confirmClean = true }
            )
            .frame(width: 292)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func hubCard(_ row: SpaceCleanupRow) -> some View {
        HStack(spacing: AppSpacing.md) {
            SelectionCheckbox(
                isSelected: Binding(
                    get: { includedSources.contains(row.source) },
                    set: { isOn in
                        if isOn {
                            includedSources.insert(row.source)
                        } else {
                            includedSources.remove(row.source)
                        }
                    }
                ),
                size: 20
            )

            Button {
                open(row.source)
            } label: {
                HStack(spacing: AppSpacing.md) {
                    AppIconTile(
                        systemName: row.source.systemImage,
                        size: 48,
                        iconSize: 20,
                        cornerRadius: AppRadius.lg,
                        style: .tint(row.source.tint)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.source.title)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(row.source.subtitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteFormat.string(from: row.snapshot.bytes))
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                        Text("\(row.snapshot.selectedCount) item\(row.snapshot.selectedCount == 1 ? "" : "s")")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    LinearGradient(
                        colors: [row.source.tint.opacity(0.10), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
        .appShadow(AppShadow.card)
        .appHoverLift()
        .opacity(includedSources.contains(row.source) ? 1 : 0.55)
    }

    private var junkDetailList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Junk categories",
                subtitle: "Sensitive items stay unchecked by default"
            ) {
                SizeBadge(value: ByteFormat.string(from: snapshot(for: .junk).bytes), emphasis: .accent)
            }

            if space.categories.isEmpty {
                Text("No junk categories in authorized folders.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(categoriesBinding) { $category in
                            categoryCard($category)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func categoryCard(_ category: Binding<SpaceCategory>) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Button {
                    category.wrappedValue.isExpanded.toggle()
                } label: {
                    HStack {
                        Image(systemName: category.wrappedValue.systemImage)
                            .foregroundStyle(AppDestination.spaceCleaner.tint)
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
                                if item.isRootOwned {
                                    StatusBadge(title: FileOwnership.rootOwnedLabel, style: .danger)
                                        .help(FileOwnership.rootOwnedTooltip)
                                } else if item.isSensitive {
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

    private func open(_ source: SpaceCleanupSource) {
        switch source {
        case .junk:
            showingJunkDetail = true
        case .largeFiles:
            appState.navigate(to: .largeFiles)
        case .duplicates:
            appState.navigate(to: .duplicates)
        case .leftovers:
            appState.navigate(to: .orphans)
        }
    }

    private func snapshot(for source: SpaceCleanupSource) -> SpaceCleanupSnapshot {
        switch source {
        case .junk:
            let items = space.categories.flatMap(\.items).filter(\.isSelected)
            return SpaceCleanupSnapshot(bytes: items.reduce(0) { $0 + $1.byteSize }, selectedCount: items.count, urls: items.map(\.url), itemCount: space.categories.flatMap(\.items).count)
        case .largeFiles:
            let items = scanResults.largeFiles.items.filter(\.isSelected)
            return SpaceCleanupSnapshot(bytes: items.reduce(0) { $0 + $1.byteSize }, selectedCount: items.count, urls: items.map(\.url), itemCount: scanResults.largeFiles.items.count)
        case .duplicates:
            let files = scanResults.duplicates.groups.flatMap(\.files).filter(\.isSelected)
            return SpaceCleanupSnapshot(bytes: files.reduce(0) { $0 + $1.byteSize }, selectedCount: files.count, urls: files.map(\.url), itemCount: scanResults.duplicates.groups.flatMap(\.files).count)
        case .leftovers:
            let items = scanResults.orphans.items.filter(\.isSelected)
            return SpaceCleanupSnapshot(bytes: items.reduce(0) { $0 + $1.byteSize }, selectedCount: items.count, urls: items.map(\.url), itemCount: scanResults.orphans.items.count)
        }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert(SmartScanAggregator.canonicalPath($0)).inserted }
    }

    private func rescan() {
        isRescanning = true
        showingJunkDetail = false
        Task {
            await appState.runSmartScan()
            isRescanning = false
        }
    }

    private func clean() async {
        isCleaning = true
        let urls = selectedURLs

        let selectedItems = space.categories.flatMap(\.items).filter(\.isSelected)
        let rootOwnedItems = selectedItems.filter(\.isRootOwned)

        if !rootOwnedItems.isEmpty {
            let names = rootOwnedItems.prefix(3).map(\.name).joined(separator: ", ")
            let more = rootOwnedItems.count > 3 ? " and \(rootOwnedItems.count - 3) more" : ""
            statusMessage = FileOwnership.skippedRootOwnedStatus(names: names, more: more)

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
            statusMessage = "Moved \(result.trashedCount) items. \(result.errors.count) error(s) — see Activity log."
        } else {
            statusMessage = "Moved \(result.trashedCount) items (\(ByteFormat.string(from: result.freedBytes)))."
        }
        isCleaning = false
    }
}

// MARK: - Hub model

private enum SpaceCleanupSource: String, CaseIterable, Identifiable {
    case junk
    case largeFiles
    case duplicates
    case leftovers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .junk: return "Junk"
        case .largeFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        case .leftovers: return "App Leftovers"
        }
    }

    var subtitle: String {
        switch self {
        case .junk: return "System caches, logs, and temporary files"
        case .largeFiles: return "Oversized files in authorized folders"
        case .duplicates: return "Identical copies you can review"
        case .leftovers: return "Files left behind by missing apps"
        }
    }

    var systemImage: String {
        switch self {
        case .junk: return "trash.fill"
        case .largeFiles: return "doc.on.doc"
        case .duplicates: return "rectangle.on.rectangle"
        case .leftovers: return "tray.fill"
        }
    }

    var tint: Color {
        switch self {
        case .junk: return AppColors.success
        case .largeFiles: return AppColors.accent
        case .duplicates: return AppColors.toolPurple
        case .leftovers: return AppColors.warning
        }
    }
}

private struct SpaceCleanupSnapshot {
    var bytes: Int64
    var selectedCount: Int
    var urls: [URL]
    var itemCount: Int
}

private struct SpaceCleanupRow: Identifiable {
    let source: SpaceCleanupSource
    let snapshot: SpaceCleanupSnapshot
    var id: String { source.id }
}

// MARK: - Summary rail

private struct SpaceCleanerSummaryRail: View {
    let rows: [SpaceCleanupRow]
    let selectedBytes: Int64
    let recoverableTotal: Int64
    var isCleaning: Bool
    var isDisabled: Bool
    var onClean: () -> Void

    private var progress: Double {
        min(max(Double(selectedBytes) / Double(max(recoverableTotal, 1)), 0), 1)
    }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.sm) {
                Text("Cleanup summary")
                    .font(AppTypography.calloutMedium)
                    .foregroundStyle(AppColors.textSecondary)
                Text("Ready to recover")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            SpaceCleanerSummaryRing(bytes: selectedBytes, progress: max(progress, selectedBytes > 0 ? 0.08 : 0))

            VStack(spacing: AppSpacing.sm) {
                ForEach(rows) { row in
                    HStack(spacing: AppSpacing.sm) {
                        AppIconTile(
                            systemName: row.source.systemImage,
                            size: 28,
                            iconSize: 12,
                            cornerRadius: AppRadius.sm,
                            style: .tint(row.source.tint)
                        )
                        Text(row.source.title)
                            .font(AppTypography.calloutMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        Text(ByteFormat.string(from: row.snapshot.bytes))
                            .font(AppTypography.calloutMedium)
                            .foregroundStyle(AppColors.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            Spacer(minLength: AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                Button(action: onClean) {
                    HStack(spacing: AppSpacing.sm) {
                        if isCleaning {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppColors.textOnAccent)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text("Move to Trash")
                            .font(AppTypography.headline)
                    }
                    .foregroundStyle(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                            .fill(isDisabled ? AppGradients.accentButtonDisabled : AppGradients.accentButton)
                    )
                    .appShadow(isDisabled || isCleaning ? AppShadow.soft : AppShadow.button)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled || isCleaning)

                Text("Selected items will be moved to Trash. Nothing is permanently deleted.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxxl, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxxl, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
        .appShadow(AppShadow.card)
    }
}

private struct SpaceCleanerSummaryRing: View {
    let bytes: Int64
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.progressTrack, lineWidth: 14)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AppColors.success,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.success.opacity(0.35), radius: 8, y: 0)

            VStack(spacing: 4) {
                Text(ByteFormat.string(from: bytes))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("selected")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .frame(width: 148, height: 148)
    }
}
