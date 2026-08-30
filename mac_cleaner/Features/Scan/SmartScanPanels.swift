//
//  SmartScanPanels.swift
//  mac_cleaner
//

import SwiftUI

struct SmartScanScanningCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    var body: some View {
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

                    SecondaryButton(title: "Cancel", icon: "xmark", size: .compact) {
                        appState.cancelSmartScan()
                    }
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
}

struct SmartScanResultHero: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
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
                        recoveryStat(ByteFormat.string(from: summary.safeToRemoveSize), "safe to remove", AppColors.success)
                        recoveryStat(ByteFormat.string(from: summary.reviewRecommendedSize), "review recommended", AppColors.warning)
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
}

struct SmartScanJunkCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub
    var isCleaning: Bool
    var onClean: () -> Void

    var body: some View {
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
                    Text("Clean \(ByteFormat.string(from: scanResults.space.junkBytes)) of safe junk")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(scanResults.space.junkItemCount) selected regenerable items · backups and Docker stay unchecked")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                SizeBadge(value: ByteFormat.string(from: scanResults.space.junkBytes), emphasis: .accent)

                PrimaryButton(
                    title: "Clean Junk",
                    icon: "trash",
                    isLoading: isCleaning,
                    isDisabled: scanResults.space.junkItemCount == 0 || session.isScanning,
                    size: .compact,
                    action: onClean
                )

                SecondaryButton(title: "Review", size: .compact) {
                    appState.navigate(to: .spaceCleaner)
                }
            }
        }
    }
}

struct SmartScanOpportunitiesSection: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    var searchText: String

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
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
}

struct SmartScanCategoriesGrid: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    var searchText: String

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
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
}

struct SmartScanCoverageCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
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
}
