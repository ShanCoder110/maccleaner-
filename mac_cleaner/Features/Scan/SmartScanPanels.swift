//
//  SmartScanPanels.swift
//  mac_cleaner
//

import SwiftUI

struct SmartScanScanningCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    var body: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl) {
            HStack(alignment: .top, spacing: AppSpacing.xxl) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.14))
                        .frame(width: 148, height: 148)
                        .blur(radius: 16)
                        .scaleEffect(session.isScanning ? 1.08 : 1)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: session.isScanning
                        )
                    Circle()
                        .fill(AppColors.accentMuted)
                        .frame(width: 124, height: 124)
                    AppProgressRing(
                        progress: session.progress,
                        lineWidth: 8,
                        size: 104,
                        showsPercent: true
                    )
                }
                .frame(width: 148, height: 148)

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    StatusBadge(
                        title: "Scanning · \(session.progressPercent)%",
                        style: .info,
                        icon: "circle.dotted"
                    )

                    Text("Scanning your Mac…")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(session.progressLabel)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)

                    AppProgressBar(progress: session.progress, height: 5)
                        .padding(.trailing, AppSpacing.xxl)

                    VStack(spacing: 0) {
                        ForEach(Array(session.scanStages.enumerated()), id: \.element.id) { index, stage in
                            stageRow(stage)
                            if index < session.scanStages.count - 1 {
                                Rectangle()
                                    .fill(AppColors.borderSubtle)
                                    .frame(height: 1)
                                    .padding(.leading, 28)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                    )

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
                .font(AppTypography.calloutMedium)
                .foregroundStyle(
                    stage.status == .pending ? AppColors.textTertiary : AppColors.textPrimary
                )
            Spacer(minLength: 0)
            if let detail = stage.detail {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .monospacedDigit()
            } else if stage.status == .running {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
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

    @State private var appeared = false
    @State private var checkPulse = false

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl) {
            HStack(alignment: .top, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(AppColors.success.opacity(0.16))
                                .frame(width: 28, height: 28)
                                .scaleEffect(checkPulse ? 1.35 : 1)
                                .opacity(checkPulse ? 0.25 : 0.7)

                            Image(systemName: summary.hasMeaningfulRecovery ? "checkmark.circle.fill" : "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(summary.hasMeaningfulRecovery ? AppColors.success : AppColors.accent)
                                .scaleEffect(appeared ? 1 : 0.4)
                        }

                        StatusBadge(
                            title: summary.hasMeaningfulRecovery ? "Scan complete" : "All caught up",
                            style: summary.hasMeaningfulRecovery ? .success : .info,
                            icon: summary.hasMeaningfulRecovery ? "checkmark.circle.fill" : "sparkles"
                        )
                    }

                    if summary.hasMeaningfulRecovery {
                        Text("You can recover")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(ByteFormat.string(from: summary.recoverableSize))
                            .font(AppTypography.largeTitle)
                            .foregroundStyle(AppGradients.accentButton)
                            .monospacedDigit()
                    } else {
                        Text("You're all caught up")
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("No significant cleanup opportunities in your authorized folders.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 420, alignment: .leading)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        if summary.hasMeaningfulRecovery {
                            PrimaryButton(title: "Review Cleanup", icon: "arrow.right", size: .large) {
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
                        SecondaryButton(title: "Permissions", icon: "folder.badge.plus") {
                            appState.openManagePermissions()
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }

                Spacer(minLength: AppSpacing.md)

                if summary.hasMeaningfulRecovery {
                    VStack(spacing: AppSpacing.sm) {
                        recoveryStatCard(
                            value: ByteFormat.string(from: summary.safeToRemoveSize),
                            label: "Safe to remove",
                            color: AppColors.success,
                            fill: AppColors.successMuted,
                            icon: "checkmark.shield.fill"
                        )
                        recoveryStatCard(
                            value: ByteFormat.string(from: summary.reviewRecommendedSize),
                            label: "Review recommended",
                            color: AppColors.warning,
                            fill: AppColors.warningMuted,
                            icon: "eye.fill"
                        )
                    }
                    .frame(width: 200)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.7).repeatCount(2, autoreverses: true)) {
                checkPulse = true
            }
        }
    }

    private func recoveryStatCard(
        value: String,
        label: String,
        color: Color,
        fill: Color,
        icon: String
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(fill)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTypography.headline)
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(fill.opacity(0.55))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.sm)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct SmartScanJunkCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub
    var isCleaning: Bool
    var onClean: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.successMuted)
                    .frame(width: 48, height: 48)
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.success)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Clean \(ByteFormat.string(from: scanResults.space.junkBytes)) of safe junk")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(scanResults.space.junkItemCount) regenerable items selected · backups and Docker stay unchecked")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: AppSpacing.md)

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
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColors.success)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.success.opacity(0.2), lineWidth: 1)
        )
        .appShadow(AppShadow.card)
    }
}

struct SmartScanOpportunitiesSection: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    var searchText: String

    private var summary: SmartScanSummary { session.summary }

    private var filtered: [SmartScanOpportunity] {
        summary.topOpportunities.filter {
            searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Biggest opportunities",
                subtitle: "Start where you’ll recover the most"
            )

            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                    opportunityRow(item, rank: index + 1)
                }
            }
        }
    }

    private func opportunityRow(_ item: SmartScanOpportunity, rank: Int) -> some View {
        Button {
            if let destination = item.destination {
                appState.navigate(to: destination)
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Text("\(rank)")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(item.destination?.tint ?? AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill((item.destination?.tint ?? AppColors.accent).opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    StatusBadge(title: item.safety.shortTitle, style: item.safety.badgeStyle)
                }

                Spacer(minLength: 0)

                SizeBadge(value: item.sizeLabel, emphasis: .accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .appHoverLift()
    }
}

struct SmartScanCategoriesGrid: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    var searchText: String

    private var summary: SmartScanSummary { session.summary }

    private var visibleCategories: [SmartScanCategoryResult] {
        session.categorySummaries.filter { category in
            let matchesSearch = searchText.isEmpty
                || category.title.localizedCaseInsensitiveContains(searchText)
            let hasContent = category.id == "apps"
                ? category.itemCount > 0
                : category.itemCount > 0 && category.recoverableBytes > 0
            return matchesSearch && hasContent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Cleanup categories",
                subtitle: summary.folderAccessLimited
                    ? "Some categories are limited — authorize more folders to expand coverage."
                    : "Open a category to review items"
            )

            if visibleCategories.isEmpty {
                Text(searchText.isEmpty ? "No categories with recoverable items." : "No categories match your search.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.sm)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md),
                    ],
                    spacing: AppSpacing.md
                ) {
                    ForEach(visibleCategories) { category in
                        categoryCard(category)
                    }
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
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top) {
                    AppIconTile(
                        systemName: category.systemImage,
                        size: 40,
                        iconSize: 15,
                        cornerRadius: AppRadius.md,
                        style: .tint(category.destination?.tint ?? AppColors.accent)
                    )

                    Spacer(minLength: 0)

                    if category.id == "apps" {
                        Text("\(category.itemCount)")
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.controlFillSecondary)
                            )
                    } else {
                        SizeBadge(
                            value: category.recoverableBytes > 0 ? category.recoverableLabel : category.sizeLabel,
                            emphasis: .prominent
                        )
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(category.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xs) {
                        StatusBadge(title: category.safety.shortTitle, style: category.safety.badgeStyle)
                        if category.id != "apps" {
                            Text("·")
                                .foregroundStyle(AppColors.textTertiary)
                            Text("\(category.itemCount) items")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        } else {
                            Text("·")
                                .foregroundStyle(AppColors.textTertiary)
                            Text("apps")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    Text(category.explanation)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .frame(minHeight: 32, alignment: .topLeading)
                }

                HStack(spacing: AppSpacing.xxs) {
                    Text("Review")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                    Spacer(minLength: 0)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .appShadow(AppShadow.card)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
        .appHoverLift()
        .disabled(session.isScanning)
    }
}

struct SmartScanCoverageCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(AppColors.controlFillSecondary)
                    .frame(width: 32, height: 32)
                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Coverage")
                    .font(AppTypography.calloutMedium)
                    .foregroundStyle(AppColors.textPrimary)

                if summary.coverageTitles.isEmpty {
                    Text("No authorized folders yet — apps still listed from /Applications.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                } else {
                    Text(summary.coverageTitles.joined(separator: " · "))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            SecondaryButton(title: "Manage", icon: "folder.badge.plus", size: .compact) {
                appState.openManagePermissions()
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
        )
    }
}
