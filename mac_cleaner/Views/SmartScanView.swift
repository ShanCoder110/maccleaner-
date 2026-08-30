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
                subtitle: "See what you can safely recover — and what to review next",
                searchText: $searchText
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    if !bookmarks.hasAnyAccess {
                        permissionNeededCard
                    } else {
                        FolderAccessBanner()
                    }

                    if session.isScanning {
                        SmartScanScanningCard()
                    } else if session.hasResults {
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
        if !bookmarks.hasAnyAccess {
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
