//
//  SmartScanView.swift
//  mac_cleaner
//
//  Decision-oriented cleanup overview built on ScanSessionStore.
//

import SwiftUI
import AppKit

struct SmartScanView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var confirmCleanJunk = false
    @State private var isCleaningJunk = false
    @State private var statusMessage = ""

    private var session: ScanSessionStore { appState.scanSession }
    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Smart Scan",
                subtitle: "See what you can safely recover — and what to review next",
                searchText: $searchText
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    if !appState.bookmarks.hasAnyAccess {
                        permissionNeededCard
                    } else {
                        FolderAccessBanner()
                    }

                    if session.isScanning {
                        scanningCard
                    } else if session.hasResults {
                        resultHero
                        if summary.resultsMayBeStale {
                            staleBanner
                        }
                        if !summary.scannerWarnings.isEmpty {
                            warningsBanner
                        }
                        if session.junkItemCount > 0 {
                            junkCard
                        }
                        if !summary.topOpportunities.isEmpty {
                            opportunitiesSection
                        }
                        categoriesGrid
                        coverageCard
                    } else {
                        readyHero
                    }

                    tipsCard

                    Text("MacCleaner+ only scans folders you authorize. Files are moved to Trash, never permanently deleted.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.contentInset)
            }
        }
        .background(AppColors.background)
        .onAppear {
            DispatchQueue.main.async {
                appState.refreshDiskStats()
                if session.hasResults {
                    session.rebuildSummaries()
                }
            }
        }
        .confirmationDialog(
            "Clean selected junk?",
            isPresented: $confirmCleanJunk,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await cleanJunk() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(ByteFormat.string(from: session.junkBytes))\n\(session.junkItemCount) items\n\nEverything will be moved to Trash. Nothing will be permanently deleted.")
        }
    }

    // MARK: - Ready / permission

    private var permissionNeededCard: some View {
        AppCard(radius: AppRadius.xxxl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                StatusBadge(title: "Folder access needed", style: .warning, icon: "folder.badge.questionmark")
                Text("Smart Scan needs folder access")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                Text("MacCleaner+ only scans folders you authorize. Applications can still be listed from /Applications.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "Manage Permissions", icon: "folder.badge.plus") {
                        appState.openManagePermissions()
                    }
                    SecondaryButton(title: "Scan Anyway") {
                        Task { await appState.runSmartScan() }
                    }
                }
            }
        }
    }

    private var readyHero: some View {
        AppCard(radius: AppRadius.xxxl) {
            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                AppProgressRing(progress: 0, lineWidth: 6, size: 88, showsPercent: false)
                    .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    StatusBadge(title: "Ready", style: .neutral, icon: "sparkles")
                    Text("See what is using your authorized storage")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Scan only looks inside folders you authorize.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(appState.diskFreeLabel) free")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)

                    HStack(spacing: AppSpacing.sm) {
                        PrimaryButton(title: "Scan Now", icon: "magnifyingglass") {
                            Task { await appState.runSmartScan() }
                        }
                        SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus") {
                            appState.openManagePermissions()
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Scanning

    private var scanningCard: some View {
        AppCard(radius: AppRadius.xxxl) {
            HStack(alignment: .top, spacing: AppSpacing.xxl) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentMuted.opacity(0.55))
                        .frame(width: 118, height: 118)
                        .scaleEffect(1.06)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: session.isScanning)
                    AppProgressRing(
                        progress: session.progress,
                        lineWidth: 8,
                        size: 104,
                        showsPercent: true
                    )
                }
                .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    StatusBadge(
                        title: "Scanning \(session.progressPercent)%",
                        style: .info,
                        icon: "circle.dotted"
                    )
                    Text("Scanning your Mac…")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(session.progressLabel)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(session.scanStages) { stage in
                            stageRow(stage)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func stageRow(_ stage: SmartScanStage) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: stageIcon(stage.status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(stageColor(stage.status))
                .frame(width: 16)
            Text(stage.title)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let detail = stage.detail {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func stageIcon(_ status: SmartScanStageStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .running: return "arrow.right.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private func stageColor(_ status: SmartScanStageStatus) -> Color {
        switch status {
        case .pending: return AppColors.textTertiary
        case .running: return AppColors.accent
        case .completed: return AppColors.success
        case .failed: return AppColors.warning
        case .skipped: return AppColors.textTertiary
        }
    }

    // MARK: - Results

    private var resultHero: some View {
        AppCard(radius: AppRadius.xxxl) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                StatusBadge(
                    title: summary.hasMeaningfulRecovery ? "Scan complete" : "You're all caught up",
                    style: summary.hasMeaningfulRecovery ? .success : .info,
                    icon: summary.hasMeaningfulRecovery ? "checkmark.circle.fill" : "sparkles"
                )

                if summary.hasMeaningfulRecovery {
                    Text("You can recover")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(ByteFormat.string(from: summary.recoverableSize))
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    HStack(spacing: AppSpacing.xl) {
                        recoveryStat(
                            ByteFormat.string(from: summary.safeToRemoveSize),
                            "safe to remove",
                            AppColors.success
                        )
                        recoveryStat(
                            ByteFormat.string(from: summary.reviewRecommendedSize),
                            "review recommended",
                            AppColors.warning
                        )
                    }
                } else {
                    Text("You're all caught up")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("No significant cleanup opportunities were found in your authorized folders.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let date = summary.lastScanDate {
                    Text("Last scanned · \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                HStack(spacing: AppSpacing.sm) {
                    if summary.hasMeaningfulRecovery {
                        PrimaryButton(title: "Review Cleanup", icon: "arrow.right") {
                            if let first = summary.topOpportunities.first?.destination {
                                appState.navigate(to: first)
                            } else {
                                appState.navigate(to: .spaceCleaner)
                            }
                        }
                    }
                    SecondaryButton(title: "Scan Again", icon: "arrow.clockwise") {
                        Task { await appState.runSmartScan() }
                    }
                    SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus") {
                        appState.openManagePermissions()
                    }
                }
            }
        }
    }

    private func recoveryStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private var staleBanner: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(AppColors.warning)
                Text("Results may have changed since the last scan.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                SecondaryButton(title: "Scan Again", size: .compact) {
                    Task { await appState.runSmartScan() }
                }
            }
        }
    }

    private var warningsBanner: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Some results couldn’t be calculated.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                ForEach(summary.scannerWarnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var junkCard: some View {
        AppCard(radius: AppRadius.xxl) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.successMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: "trash")
                        .foregroundStyle(AppColors.success)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clean \(ByteFormat.string(from: session.junkBytes)) of safe junk")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(session.junkItemCount) selected cache/log/AI items · sensitive items stay excluded")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                SizeBadge(value: ByteFormat.string(from: session.junkBytes), emphasis: .accent)

                PrimaryButton(
                    title: "Clean Junk",
                    icon: "trash",
                    isLoading: isCleaningJunk,
                    isDisabled: session.junkItemCount == 0 || session.isScanning,
                    size: .compact
                ) {
                    if appState.requireProForCleanJunk() {
                        confirmCleanJunk = true
                    }
                }

                SecondaryButton(title: "Review", size: .compact) {
                    appState.navigate(to: .spaceCleaner)
                }
            }
        }
    }

    private var opportunitiesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Biggest opportunities",
                subtitle: "Where your attention is most valuable"
            )

            VStack(spacing: AppSpacing.sm) {
                ForEach(summary.topOpportunities.filter {
                    searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                }) { item in
                    AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
                        HStack(spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                StatusBadge(title: item.safety.shortTitle, style: item.safety.badgeStyle)
                            }
                            Spacer()
                            SizeBadge(value: item.sizeLabel, emphasis: .accent)
                            SecondaryButton(title: "Review", size: .compact) {
                                if let destination = item.destination {
                                    appState.navigate(to: destination)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Cleanup categories",
                subtitle: summary.folderAccessLimited
                    ? "Some categories are limited because their folders are not authorized."
                    : "Open a category to review — results stay available when you navigate away"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)],
                spacing: AppSpacing.md
            ) {
                ForEach(session.categorySummaries.filter { category in
                    let matchesSearch = searchText.isEmpty
                        || category.title.localizedCaseInsensitiveContains(searchText)
                    // Hide empty cleanup cards; keep Applications when inventory found apps.
                    let hasContent = category.id == "apps"
                        ? category.itemCount > 0
                        : category.itemCount > 0 && category.recoverableBytes > 0
                    return matchesSearch && hasContent
                }) { category in
                    categoryCard(category)
                }
            }
        }
    }

    private func categoryCard(_ category: SmartScanCategoryResult) -> some View {
        Button {
            if let destination = category.destination {
                appState.navigate(to: destination)
            }
        } label: {
            AppCard(padding: AppSpacing.lg, radius: AppRadius.xxl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(AppColors.accentMuted)
                                .frame(width: 36, height: 36)
                            Image(systemName: category.systemImage)
                                .foregroundStyle(AppColors.accent)
                        }
                        Spacer()
                        if category.id == "apps" {
                            Text("\(category.itemCount) apps")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        } else {
                            SizeBadge(
                                value: category.recoverableBytes > 0 ? category.recoverableLabel : category.sizeLabel,
                                emphasis: .prominent
                            )
                        }
                    }

                    Text(category.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    if category.id != "apps" {
                        Text("\(category.itemCount) items")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    StatusBadge(title: category.safety.title, style: category.safety.badgeStyle)

                    Text(category.explanation)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)

                    HStack {
                        Spacer()
                        Text("Review")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(session.isScanning)
    }

    private var coverageCard: some View {
        AppCard(padding: AppSpacing.lg, radius: AppRadius.xxl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Coverage")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if summary.coverageTitles.isEmpty {
                    Text("No authorized folders yet. Applications were still listed from /Applications.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("Scanned \(summary.coverageTitles.count) authorized location\(summary.coverageTitles.count == 1 ? "" : "s")")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(summary.coverageTitles.joined(separator: " · "))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                    appState.openManagePermissions()
                }
            }
        }
    }

    private var tipsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Helpful tips")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(contextualTip)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Use System Settings → General → Storage for Apple’s recommendations. Empty Trash from Finder when you are ready to permanently free space.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                SecondaryButton(title: "Open Storage Settings", size: .compact) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private var contextualTip: String {
        if !appState.bookmarks.hasAnyAccess {
            return "Grant Downloads, Documents, or Caches access to find more cleanup opportunities."
        }
        guard session.hasResults else {
            return "Run Smart Scan to see safe cleanup and review recommendations in your authorized folders."
        }
        if !summary.hasMeaningfulRecovery {
            return "Your authorized folders don’t currently contain major cleanup opportunities."
        }
        if let top = summary.topOpportunities.first {
            switch top.id {
            case "large":
                return "Large files are often the fastest way to recover storage. Review your largest files."
            case "dupes":
                return "You have duplicate files using significant storage. Review them before removing copies."
            case "space":
                return "Caches and logs look like the safest place to start recovering space."
            case "orphans":
                return "App leftovers may belong to uninstalled apps — review carefully before cleaning."
            default:
                break
            }
        }
        return "Start with safe items, then review larger or ambiguous files."
    }

    private func cleanJunk() async {
        isCleaningJunk = true
        let urls = session.junkURLs
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        session.clearAfterClean(removedURLs: removed)
        statusMessage = "Moved \(result.trashedCount) junk items (\(ByteFormat.string(from: result.freedBytes)))."
        if !result.errors.isEmpty {
            statusMessage += " \(result.errors.count) items need permission or couldn’t be moved."
        }
        appState.refreshDiskStats()
        isCleaningJunk = false
    }
}
