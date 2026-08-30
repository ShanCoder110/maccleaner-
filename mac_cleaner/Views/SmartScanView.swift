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
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub
    @EnvironmentObject private var bookmarks: BookmarkStore

    @State private var searchText = ""
    @State private var confirmCleanJunk = false
    @State private var isCleaningJunk = false
    @State private var statusMessage = ""

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Smart Scan",
                subtitle: toolbarSubtitle,
                searchText: $searchText
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if !bookmarks.hasAnyAccess {
                        permissionNeededCard
                    } else if !session.isScanning && !session.hasResults {
                        FolderAccessBanner()
                    }

                    if session.isScanning {
                        SmartScanScanningCard()
                    } else if session.hasResults {
                        resultsContent
                    } else if bookmarks.hasAnyAccess {
                        readyHero
                    }

                    if !session.isScanning {
                        footerStrip
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.contentInset)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(Color.clear)
        .onAppear {
            DispatchQueue.main.async {
                appState.refreshDiskStats()
                if session.hasResults {
                    appState.rebuildScanSummaries()
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
            Text("\(ByteFormat.string(from: scanResults.space.junkBytes))\n\(scanResults.space.junkItemCount) items\n\nEverything will be moved to Trash. Nothing will be permanently deleted.")
        }
    }

    private var toolbarSubtitle: String {
        if session.isScanning {
            return session.progressLabel
        }
        if session.hasResults, let date = summary.lastScanDate {
            return "Last scanned · \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Find what you can safely recover — then review the rest"
    }

    @ViewBuilder
    private var resultsContent: some View {
        SmartScanResultHero()

        if summary.resultsMayBeStale {
            staleBanner
        }

        if !summary.scannerWarnings.isEmpty {
            warningsBanner
        }

        if scanResults.space.junkItemCount > 0 {
            SmartScanJunkCard(isCleaning: isCleaningJunk) {
                if appState.requireProForCleanJunk() {
                    confirmCleanJunk = true
                }
            }
        }

        if !summary.topOpportunities.isEmpty {
            SmartScanOpportunitiesSection(searchText: searchText)
        }

        SmartScanCategoriesGrid(searchText: searchText)
        SmartScanCoverageCard()
    }

    // MARK: - Ready / permission

    private var permissionNeededCard: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl) {
            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                AppIconTile(
                    systemName: "folder.badge.questionmark",
                    size: 88,
                    iconSize: 32,
                    cornerRadius: AppRadius.xxl,
                    style: .warning
                )

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    StatusBadge(title: "Access needed", style: .warning, icon: "lock.fill")
                    Text("Authorize folders to unlock Smart Scan")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("MacCleaner+ only looks inside folders you choose. Applications can still be listed from /Applications.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppSpacing.sm) {
                        PrimaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .large) {
                            appState.openManagePermissions()
                        }
                        SecondaryButton(title: "Scan Anyway") {
                            Task { await appState.runSmartScan() }
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var readyHero: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl) {
            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 148, height: 148)
                        .blur(radius: 14)

                    Circle()
                        .strokeBorder(AppColors.accent.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 132, height: 132)

                    AppIconTile(
                        systemName: "sparkles",
                        size: 88,
                        iconSize: 34,
                        cornerRadius: 44,
                        style: .accent
                    )
                }
                .frame(width: 148, height: 148)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    StatusBadge(title: "Ready to scan", style: .info, icon: "sparkles")

                    Text("See what’s using space in your folders")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Smart Scan checks caches, large files, duplicates, leftovers, and more — only where you’ve granted access.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460, alignment: .leading)

                    HStack(spacing: AppSpacing.sm) {
                        metricChip(icon: "internaldrive", label: "\(appState.diskFreeLabel) free")
                        if !bookmarks.folders.isEmpty {
                            metricChip(
                                icon: "folder",
                                label: "\(bookmarks.folders.count) folder\(bookmarks.folders.count == 1 ? "" : "s")"
                            )
                        }
                    }
                    .padding(.top, AppSpacing.xxs)

                    HStack(spacing: AppSpacing.sm) {
                        PrimaryButton(title: "Scan Now", icon: "magnifyingglass", size: .large) {
                            Task { await appState.runSmartScan() }
                        }
                        SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus") {
                            appState.openManagePermissions()
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func metricChip(icon: String, label: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.accent)
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(AppColors.surfaceSecondary)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Banners & footer

    private var staleBanner: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.warning)
            Text("Results may have changed since the last scan.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 0)
            SecondaryButton(title: "Scan Again", size: .compact) {
                Task { await appState.runSmartScan() }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.warningMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.warning.opacity(0.22), lineWidth: 1)
        )
    }

    private var warningsBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warning)
                Text("Some results couldn’t be calculated")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
            }
            ForEach(summary.scannerWarnings, id: \.self) { warning in
                Text(warning)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.leading, AppSpacing.lg)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    private var footerStrip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !session.hasResults {
                tipRow
            }

            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.top, 1)
                Text("Only scans folders you authorize. Files go to Trash — never permanently deleted from here.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("System Storage")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private var tipRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.top, 1)
            Text(contextualTip)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.accentSubtle)
        )
    }

    private var contextualTip: String {
        if !bookmarks.hasAnyAccess {
            return "Grant Downloads, Documents, or Caches access to find more cleanup opportunities."
        }
        return "Run Smart Scan to see safe cleanup first, then review larger or ambiguous files."
    }

    private func cleanJunk() async {
        isCleaningJunk = true
        let urls = scanResults.space.junkURLs
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        appState.clearScanResultsAfterClean(removedURLs: removed)
        statusMessage = "Moved \(result.trashedCount) junk items (\(ByteFormat.string(from: result.freedBytes)))."
        if !result.errors.isEmpty {
            statusMessage += " \(result.errors.count) items need permission or couldn’t be moved."
        }
        appState.refreshDiskStats()
        isCleaningJunk = false
    }
}
