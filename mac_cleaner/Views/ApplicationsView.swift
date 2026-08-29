//
//  ApplicationsView.swift
//  mac_cleaner
//
//  Transparent, confidence-based application storage manager and uninstaller.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickLookUI
import Combine

struct ApplicationsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var apps: [InstalledApp] = []
    @State private var leftoversByAppID: [String: [LeftoverItem]] = [:]
    @State private var summariesByAppID: [String: AppStorageSummary] = [:]
    @State private var searchedFoldersByAppID: [String: [String]] = [:]
    @State private var loadingLeftovers: Set<String> = []
    @State private var searchText = ""
    @State private var filter: AppListFilter = .all
    @State private var sort: AppListSort = .name
    @State private var unusedThreshold: UnusedThreshold = .sixMonths
    @State private var isLoading = false
    @State private var isUninstalling = false
    @State private var showConfirmSheet = false
    @State private var showResultSheet = false
    @State private var whyItem: LeftoverItem?
    @State private var resultSummary: UninstallResultSummary?
    @State private var progress: Double = 0
    @State private var statusMessage = ""
    @State private var scopeToken = ""

    private let inventory = AppInventoryService()
    private let scanCache = LeftoverScanCache.shared

    private var filteredApps: [InstalledApp] {
        let matching = apps.filter { app in
            AppListFiltering.matches(
                app: app,
                filter: filter,
                searchText: searchText,
                unusedThreshold: unusedThreshold,
                totalDiscoveredSize: totalSize(for: app)
            )
        }
        return AppListFiltering.sorted(matching, by: sort, totalSize: totalSize(for:))
    }

    private var selectedApps: [InstalledApp] {
        apps.filter(\.isSelected)
    }

    private var selectedLeftoverItems: [LeftoverItem] {
        selectedApps.flatMap { leftoversByAppID[$0.id] ?? [] }.filter(\.isSelected)
    }

    private var filterEmptyTitle: String {
        switch filter {
        case .all: return "No applications found"
        case .selected: return "No apps selected"
        case .large: return "No large apps"
        case .unused: return "No unused apps"
        }
    }

    private var filterEmptyMessage: String {
        switch filter {
        case .all:
            return "Drop an app here or refresh the list from /Applications."
        case .selected:
            return "Select one or more apps with the checkbox to focus on them here."
        case .large:
            return "No apps at or above 500 MB (app size or discovered total) matched this filter."
        case .unused:
            return "No apps appear unused for \(unusedThreshold.title). Last-opened dates come from macOS when available and may be approximate."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Applications",
                subtitle: "See real storage, understand matches, and choose exactly what moves to Trash",
                searchText: $searchText,
                searchPlaceholder: "Search applications"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()
                controlsRow
                sectionHeader

                if isLoading {
                    ProgressView("Loading applications…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredApps.isEmpty {
                    EmptyState(
                        title: filterEmptyTitle,
                        message: filterEmptyMessage,
                        systemImage: filter == .selected ? "checkmark.circle" : (filter == .unused ? "clock" : "square.grid.2x2"),
                        primaryActionTitle: filter == .all ? "Refresh" : "Show All",
                        primaryAction: {
                            if filter == .all {
                                reload()
                            } else {
                                filter = .all
                            }
                        },
                        secondaryActionTitle: filter == .all ? nil : "Refresh",
                        secondaryAction: filter == .all ? nil : { reload() }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filteredApps) { app in
                                appAccordion(app)
                            }
                        }
                    }
                    .id("\(filter.rawValue)-\(sort.rawValue)-\(unusedThreshold.rawValue)")
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
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .onAppear {
            DispatchQueue.main.async { reload() }
            refreshScopeToken()
        }
        .onChange(of: appState.sensitivity) { _, _ in
            invalidateScansForScopeChange()
        }
        .onReceive(appState.bookmarks.objectWillChange) { _ in
            DispatchQueue.main.async {
                invalidateScansForScopeChange()
            }
        }
        .sheet(isPresented: $showConfirmSheet) {
            uninstallConfirmSheet
        }
        .sheet(isPresented: $showResultSheet) {
            if let resultSummary {
                uninstallResultSheet(resultSummary)
            }
        }
        .sheet(item: $whyItem) { item in
            whySheet(item)
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Row 1: filter chips — full labels, never compressed to "…"
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                AppFilterChipGroup(
                    options: AppListFilter.allCases.map { ($0, $0.title) },
                    selection: $filter
                )

                Spacer(minLength: 0)

                SecondaryButton(title: "Refresh", icon: "arrow.clockwise", size: .compact) {
                    reload()
                }

                PrimaryButton(
                    title: "Uninstall",
                    icon: "trash",
                    isLoading: isUninstalling,
                    isDisabled: selectedApps.isEmpty,
                    size: .compact
                ) {
                    Task { await prepareConfirm() }
                }
            }

            // Row 2: custom menus — wrap cleanly under the chips at windowed widths
            HStack(spacing: AppSpacing.sm) {
                if filter == .unused {
                    AppMenuPicker(
                        label: "Unused",
                        options: UnusedThreshold.allCases.map { ($0, $0.title) },
                        selection: $unusedThreshold,
                        minWidth: 108
                    )
                    .help("Only apps with a known last-opened date older than this period.")
                }

                AppMenuPicker(
                    label: "Sort",
                    options: AppListSort.allCases.map { ($0, $0.title) },
                    selection: $sort,
                    minWidth: 132
                )
                .help("Sort the visible application list.")

                AppMenuPicker(
                    label: "Match",
                    options: LeftoverSensitivity.allCases.map { ($0, $0.title) },
                    selection: $appState.sensitivity,
                    minWidth: 148
                )
                .help(appState.sensitivity.detail)

                Spacer(minLength: 0)
            }

            Text(filterHint)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .animation(.easeOut(duration: 0.15), value: filter)
                .animation(.easeOut(duration: 0.15), value: appState.sensitivity)
        }
    }

    private var filterHint: String {
        switch filter {
        case .all:
            return appState.sensitivity.detail
        case .selected:
            return "Showing \(filteredApps.count) selected app\(filteredApps.count == 1 ? "" : "s")."
        case .large:
            return "Showing apps ≥ 500 MB by app size or discovered total storage."
        case .unused:
            return "Showing apps unused for \(unusedThreshold.title) (approximate last-opened from macOS)."
        }
    }

    private var sectionHeader: some View {
        SectionHeader(
            title: "Installed Apps",
            subtitle: "\(filteredApps.count) apps · expand a row to review related storage"
        ) {
            SizeBadge(
                value: ByteFormat.string(from: filteredApps.reduce(0) { $0 + totalSize(for: $1) }),
                emphasis: .accent
            )
        }
    }

    // MARK: - App row

    private func appAccordion(_ app: InstalledApp) -> some View {
        let bindingSelected = binding(for: app)
        return VStack(spacing: 0) {
            SelectableAppCard(isSelected: app.isSelected) {
                toggleSelection(app.id)
            } content: {
                HStack(spacing: AppSpacing.md) {
                    SelectionCheckbox(isSelected: bindingSelected)

                    Image(nsImage: inventory.icon(for: app))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(rowMeta(for: app))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    storageBadges(for: app)

                    Button {
                        toggleExpanded(app)
                    } label: {
                        Image(systemName: app.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                    .fill(AppColors.surfaceHover)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if app.isExpanded {
                expandedPanel(for: app)
                    .padding(.top, AppSpacing.xs)
                    .padding(.leading, AppSpacing.xl)
            }
        }
    }

    private func rowMeta(for app: InstalledApp) -> String {
        var parts = ["v\(app.version)", app.locationLabel]
        if let opened = app.lastOpenedLabel {
            parts.append("Opened ~\(opened)")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func storageBadges(for app: InstalledApp) -> some View {
        if let summary = summariesByAppID[app.id], summary.lastScanDate != nil {
            VStack(alignment: .trailing, spacing: 2) {
                SizeBadge(value: summary.totalDiscoveredSize.byteLabel, emphasis: .accent)
                Text(summary.isCachedEstimate ? "Total (est.)" : "Total discovered")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        } else if loadingLeftovers.contains(app.id) {
            ProgressView().controlSize(.small)
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                SizeBadge(value: app.sizeLabel, emphasis: .prominent)
                Text("App only")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Expanded panel

    private func expandedPanel(for app: InstalledApp) -> some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                storageSummaryBlock(for: app)

                if loadingLeftovers.contains(app.id) {
                    ProgressView("Searching authorized folders…")
                } else if let leftovers = leftoversByAppID[app.id] {
                    if leftovers.filter({ $0.kind != .appBundle }).isEmpty {
                        emptyLeftoversState(for: app)
                    } else {
                        leftoverGroups(for: app, items: leftovers)
                    }
                }

                HStack {
                    SecondaryButton(title: "Rescan", icon: "arrow.clockwise", size: .compact) {
                        Task { await loadLeftovers(for: app, force: true) }
                    }
                    .disabled(loadingLeftovers.contains(app.id))
                    Spacer()
                }
            }
        }
    }

    private func storageSummaryBlock(for app: InstalledApp) -> some View {
        let summary = summariesByAppID[app.id] ?? .unscanned(appBundleSize: app.byteSize)
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Storage summary")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            summaryLine("Application", summary.appBundleSize)
            if summary.lastScanDate != nil {
                summaryLine("Related storage found", summary.relatedStorageSize)
                summaryLine("Total discovered storage", summary.totalDiscoveredSize, emphasize: true)
                if let date = summary.lastScanDate {
                    Text(summary.isCachedEstimate
                         ? "Cached estimate · scanned \(date.formatted(date: .abbreviated, time: .shortened))"
                         : "Scanned \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            } else {
                Text("Expand and scan to discover related storage. App size alone is not total storage.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func summaryLine(_ title: String, _ bytes: Int64, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasize ? AppTypography.bodyMedium : AppTypography.callout)
                .foregroundStyle(emphasize ? AppColors.textPrimary : AppColors.textSecondary)
            Spacer()
            Text(ByteFormat.string(from: bytes))
                .font(emphasize ? AppTypography.bodyMedium : AppTypography.callout)
                .foregroundStyle(emphasize ? AppColors.accent : AppColors.textPrimary)
        }
    }

    private func emptyLeftoversState(for app: InstalledApp) -> some View {
        let searched = searchedFoldersByAppID[app.id] ?? appState.bookmarks.folders.map(\.kind.title)
        let recommended: [(GrantedFolder.Kind, String)] = [
            (.applicationSupport, "Application Support"),
            (.caches, "Caches"),
            (.preferences, "Preferences"),
            (.logs, "Logs"),
            (.containers, "Containers")
        ]
        let missing = recommended.filter { kind, _ in
            !appState.bookmarks.folders.contains(where: { $0.kind == kind })
        }

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("No related files were found in the folders currently available to MacCleaner+.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            if searched.isEmpty {
                Text("No folders are authorized yet.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                Text("Searched: \(searched.joined(separator: ", "))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            if !missing.isEmpty {
                Text("Authorize more folders (like Application Support or Caches) to find leftovers, then rescan.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                    appState.openManagePermissions()
                }
            }
        }
    }

    private func leftoverGroups(for app: InstalledApp, items: [LeftoverItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(LeftoverKind.displayOrder, id: \.self) { kind in
                let group = items.filter { $0.kind == kind }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(kind.title)
                                .font(AppTypography.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text(ByteFormat.string(from: group.reduce(0) { $0 + $1.byteSize }))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }

                        ForEach(group) { item in
                            leftoverRow(app: app, item: item)
                        }
                    }
                }
            }
        }
    }

    private func leftoverRow(app: InstalledApp, item: LeftoverItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            SelectionCheckbox(isSelected: leftoverSelectionBinding(appID: app.id, itemID: item.id))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(item.displayPath)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                    .help(item.displayPath)

                HStack(spacing: AppSpacing.xs) {
                    StatusBadge(title: item.matchConfidence.title, style: item.matchConfidence.badgeStyle)
                    StatusBadge(title: item.safety.title, style: item.safety.badgeStyle)
                    if item.isSharedOrPossiblyShared {
                        StatusBadge(title: "Shared", style: .warning, icon: "person.2")
                    }
                    Button("Why is this here?") {
                        whyItem = item
                    }
                    .buttonStyle(.plain)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.accent)
                }

                if item.isSharedOrPossiblyShared, item.relatedInstalledAppNames.count > 1 {
                    Text("Also may belong to: \(item.relatedInstalledAppNames.dropFirst().joined(separator: ", "))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }

            Spacer(minLength: 0)

            SizeBadge(value: item.sizeLabel)

            IconButton(systemName: "eye", size: 28, iconSize: 11, help: "Quick Look") {
                preview(item.url)
            }
            IconButton(systemName: "folder", size: 28, iconSize: 11, help: "Reveal in Finder") {
                appState.cleaning.reveal(item.url)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sheets

    private var uninstallConfirmSheet: some View {
        let appsCount = selectedApps.count
        let relatedCount = max(0, selectedLeftoverItems.filter { $0.kind != .appBundle }.count)
        let total = selectedLeftoverItems.reduce(Int64(0)) { $0 + $1.byteSize }
        let sensitiveCount = selectedLeftoverItems.filter { $0.safety == .sensitive }.count
        let reviewCount = selectedLeftoverItems.filter { $0.safety == .reviewRecommended }.count
        let names = selectedApps.map(\.name).joined(separator: ", ")

        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Move to Trash?")
                .font(AppTypography.title)
            Text("\(names)\(relatedCount > 0 ? " and \(relatedCount) selected related item\(relatedCount == 1 ? "" : "s")" : "")")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                confirmStat("Applications", "\(appsCount)")
                confirmStat("Related files", "\(relatedCount)")
                confirmStat("Total selected storage", ByteFormat.string(from: total))
                if reviewCount > 0 {
                    confirmStat("Review recommended", "\(reviewCount)")
                }
                if sensitiveCount > 0 {
                    confirmStat("Sensitive items selected", "\(sensitiveCount)")
                }
            }

            Text("Nothing will be permanently deleted. Items move to Trash and can be restored. macOS may ask you to grant the Applications folder so uninstall can proceed.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)

            HStack {
                SecondaryButton(title: "Cancel", size: .compact) {
                    showConfirmSheet = false
                }
                SecondaryButton(title: "Review Selection", size: .compact) {
                    showConfirmSheet = false
                }
                Spacer()
                PrimaryButton(title: "Move to Trash", icon: "trash", size: .compact) {
                    showConfirmSheet = false
                    Task { await uninstallSelected() }
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(width: 480)
    }

    private func confirmStat(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value).font(AppTypography.bodyMedium)
        }
        .font(AppTypography.callout)
    }

    private func uninstallResultSheet(_ result: UninstallResultSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(result.title)
                .font(AppTypography.title)
            Text("\(result.freedLabel) moved")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.accent)
            Text("\(result.appCount) application\(result.appCount == 1 ? "" : "s") · \(result.relatedCount) related item\(result.relatedCount == 1 ? "" : "s")")
                .foregroundStyle(AppColors.textSecondary)

            if result.failedCount > 0 {
                Text("\(result.failedCount) item\(result.failedCount == 1 ? "" : "s") could not be moved.")
                    .foregroundStyle(AppColors.danger)
                if !result.errorDetails.isEmpty {
                    ScrollView {
                        Text(result.errorDetails.joined(separator: "\n"))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            }

            HStack {
                SecondaryButton(title: "Show in Trash", size: .compact) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "\(NSHomeDirectory())/.Trash")
                }
                SecondaryButton(title: "View Activity", size: .compact) {
                    showResultSheet = false
                    appState.selection = .activity
                }
                Spacer()
                PrimaryButton(title: "Done", size: .compact) {
                    showResultSheet = false
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(width: 480)
    }

    private func whySheet(_ item: LeftoverItem) -> some View {
        let appName = item.relatedInstalledAppNames.first ?? "this application"
        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Why is this here?")
                .font(AppTypography.title)
            Text(item.name)
                .font(AppTypography.headline)
            Text(item.matchReason.explanation(appName: appName, isShared: item.isSharedOrPossiblyShared))
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppSpacing.sm) {
                StatusBadge(title: item.matchConfidence.title, style: item.matchConfidence.badgeStyle)
                StatusBadge(title: item.safety.title, style: item.safety.badgeStyle)
                if item.isSharedOrPossiblyShared {
                    StatusBadge(title: "Shared or possibly shared", style: .warning)
                }
            }

            Text(item.safety.detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)

            HStack {
                Spacer()
                PrimaryButton(title: "Got it", size: .compact) {
                    whyItem = nil
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(width: 440)
    }

    // MARK: - Bindings & actions

    private func binding(for app: InstalledApp) -> Binding<Bool> {
        Binding(
            get: { apps.first(where: { $0.id == app.id })?.isSelected ?? false },
            set: { newValue in
                if let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].isSelected = newValue
                }
            }
        )
    }

    private func bindingLeftovers(for appID: String) -> Binding<[LeftoverItem]> {
        Binding(
            get: { leftoversByAppID[appID] ?? [] },
            set: { leftoversByAppID[appID] = $0 }
        )
    }

    private func leftoverSelectionBinding(appID: String, itemID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                leftoversByAppID[appID]?.first(where: { $0.id == itemID })?.isSelected ?? false
            },
            set: { newValue in
                guard var items = leftoversByAppID[appID],
                      let index = items.firstIndex(where: { $0.id == itemID }) else { return }
                items[index].isSelected = newValue
                leftoversByAppID[appID] = items
            }
        )
    }

    private func toggleSelection(_ id: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].isSelected.toggle()
    }

    private func toggleExpanded(_ app: InstalledApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isExpanded.toggle()
        if apps[index].isExpanded {
            Task { await loadLeftovers(for: apps[index], force: false) }
        }
    }

    private func totalSize(for app: InstalledApp) -> Int64 {
        if let summary = summariesByAppID[app.id], summary.lastScanDate != nil {
            return summary.totalDiscoveredSize
        }
        return app.byteSize
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = inventory.loadInstalledApps()
            DispatchQueue.main.async {
                apps = loaded
                hydrateSummariesFromCache(for: loaded)
                isLoading = false
            }
        }
    }

    private func hydrateSummariesFromCache(for loaded: [InstalledApp]) {
        let sensitivity = appState.sensitivity
        for app in loaded where !app.isSystemApp {
            if let cached = scanCache.cachedScan(for: app, bookmarks: appState.bookmarks, sensitivity: sensitivity) {
                let items = scanCache.items(from: cached)
                leftoversByAppID[app.id] = items
                searchedFoldersByAppID[app.id] = cached.searchedFolderTitles
                summariesByAppID[app.id] = AppStorageSummary.from(
                    items: items,
                    appBundleSize: app.byteSize,
                    scannedAt: cached.scannedAt,
                    cached: true
                )
            }
        }
    }

    private func loadLeftovers(for app: InstalledApp, force: Bool) async {
        // Keep lazy behavior: reuse in-memory (or hydrated cache) until Rescan.
        if !force, leftoversByAppID[app.id] != nil {
            return
        }

        if !force,
           let cached = scanCache.cachedScan(for: app, bookmarks: appState.bookmarks, sensitivity: appState.sensitivity) {
            let items = scanCache.items(from: cached)
            leftoversByAppID[app.id] = items
            searchedFoldersByAppID[app.id] = cached.searchedFolderTitles
            summariesByAppID[app.id] = AppStorageSummary.from(
                items: items,
                appBundleSize: app.byteSize,
                scannedAt: cached.scannedAt,
                cached: true
            )
            return
        }

        loadingLeftovers.insert(app.id)
        let sensitivity = appState.sensitivity
        let roots = appState.bookmarks.accessibleRootURLs
        let folderTitles = appState.bookmarks.folders.map(\.kind.title).sorted()
        let bookmarks = appState.bookmarks
        let allApps = apps
        let result = await Task.detached(priority: .userInitiated) {
            LeftoverFinderService.findLeftovers(
                for: app,
                sensitivity: sensitivity,
                allInstalledApps: allApps,
                roots: roots,
                searchedFolderTitles: folderTitles
            )
        }.value

        leftoversByAppID[app.id] = result.items
        searchedFoldersByAppID[app.id] = result.searchedFolderTitles
        summariesByAppID[app.id] = AppStorageSummary.from(
            items: result.items,
            appBundleSize: app.byteSize,
            scannedAt: result.scannedAt,
            cached: false
        )
        scanCache.store(result, for: app, bookmarks: bookmarks, sensitivity: sensitivity)
        loadingLeftovers.remove(app.id)
        appState.activityLog.log(.scan, "Found \(result.items.count) related items for \(app.name)")
    }

    private func prepareConfirm() async {
        for app in selectedApps where leftoversByAppID[app.id] == nil {
            await loadLeftovers(for: app, force: false)
        }
        showConfirmSheet = true
    }

    private func uninstallSelected() async {
        isUninstalling = true
        defer { isUninstalling = false }

        let appsSnapshot = selectedApps
        var urls: [URL] = []
        var relatedCount = 0

        for app in appsSnapshot {
            if leftoversByAppID[app.id] == nil {
                await loadLeftovers(for: app, force: false)
            }
            let leftovers = leftoversByAppID[app.id] ?? [
                LeftoverItem(
                    url: app.path,
                    kind: .appBundle,
                    byteSize: app.byteSize,
                    matchConfidence: .confirmed,
                    matchReason: .appBundleItself,
                    safety: .reviewRecommended,
                    relatedInstalledAppNames: [app.name]
                )
            ]
            let selected = leftovers.filter(\.isSelected)
            relatedCount += selected.filter { $0.kind != .appBundle }.count
            urls.append(contentsOf: selected.map(\.url))
        }

        let result = await appState.cleaning.trash(urls: urls) { value in
            progress = value
        }

        let names = appsSnapshot.map(\.name)
        resultSummary = UninstallResultSummary(
            title: names.count == 1 ? "\(names[0]) moved to Trash" : "\(names.count) apps moved to Trash",
            freedLabel: ByteFormat.string(from: result.freedBytes),
            appCount: appsSnapshot.count,
            relatedCount: relatedCount,
            failedCount: result.errors.count,
            errorDetails: result.errors
        )
        showResultSheet = true
        statusMessage = "Moved \(result.trashedCount) items to Trash (\(ByteFormat.string(from: result.freedBytes)))."

        for app in appsSnapshot {
            leftoversByAppID.removeValue(forKey: app.id)
            summariesByAppID.removeValue(forKey: app.id)
            scanCache.invalidate(appIDKey: LeftoverScanCache.cacheKey(for: app))
        }
        reload()
    }

    private func preview(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            appState.cleaning.reveal(url)
            return
        }
        QuickLookPreview.shared.preview(url: url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { object, _ in
                guard let url = object as? URL, url.pathExtension == "app" else { return }
                DispatchQueue.main.async {
                    if let installed = inventory.makeApp(from: url) {
                        if let index = apps.firstIndex(where: { $0.id == installed.id }) {
                            apps[index].isSelected = true
                            apps[index].isExpanded = true
                            Task { await loadLeftovers(for: apps[index], force: false) }
                        } else {
                            var app = installed
                            app.isSelected = true
                            app.isExpanded = true
                            apps.insert(app, at: 0)
                            Task { await loadLeftovers(for: app, force: false) }
                        }
                        statusMessage = "Ready to review \(installed.name)."
                    }
                }
            }
        }
        return true
    }

    private func refreshScopeToken() {
        scopeToken = LeftoverScanCache.scopeSignature(
            bookmarks: appState.bookmarks,
            sensitivity: appState.sensitivity
        )
    }

    private func invalidateScansForScopeChange() {
        let newToken = LeftoverScanCache.scopeSignature(
            bookmarks: appState.bookmarks,
            sensitivity: appState.sensitivity
        )
        guard newToken != scopeToken else { return }
        scopeToken = newToken
        leftoversByAppID.removeAll()
        summariesByAppID.removeAll()
        searchedFoldersByAppID.removeAll()
        // Keep disk cache; entries for other scopes simply won't match.
        // Re-hydrate estimates for the new scope if present.
        hydrateSummariesFromCache(for: apps)
        for app in apps where app.isExpanded {
            Task { await loadLeftovers(for: app, force: true) }
        }
    }
}

// MARK: - Helpers

private struct UninstallResultSummary {
    var title: String
    var freedLabel: String
    var appCount: Int
    var relatedCount: Int
    var failedCount: Int
    var errorDetails: [String]
}

private extension Int64 {
    var byteLabel: String { ByteFormat.string(from: self) }
}

/// Minimal Quick Look panel host for file previews.
private final class QuickLookPreview: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreview()
    private var previewItem: NSURL?

    func preview(url: URL) {
        previewItem = url as NSURL
        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItem == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItem
    }
}
