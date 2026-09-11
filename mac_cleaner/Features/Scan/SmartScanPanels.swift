//
//  SmartScanPanels.swift
//  mac_cleaner
//

import SwiftUI

// MARK: - Shared chrome

struct SmartScanHeroBackdrop: View {
    var tint: Color = AppColors.accent

    var body: some View {
        GeometryReader { geo in
            let maxSide = max(geo.size.width, geo.size.height)

            ZStack {
                RadialGradient(
                    colors: [
                        Color.dynamic(light: Color.white.opacity(0.52), dark: Color.white.opacity(0.08)),
                        tint.opacity(0.10),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: maxSide * 1.2
                )

                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: maxSide * 0.6, height: maxSide * 0.6)
                    .blur(radius: 64)
                    .position(x: geo.size.width * 0.08, y: geo.size.height * 0.18)

                Circle()
                    .fill(AppColors.toolPurple.opacity(0.10))
                    .frame(width: maxSide * 0.5, height: maxSide * 0.5)
                    .blur(radius: 56)
                    .position(x: geo.size.width * 0.94, y: geo.size.height * 0.88)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

struct SmartScanOrb: View {
    enum Mode {
        case idle
        case scanning(Double)
        case complete(Bool)
    }

    var mode: Mode
    var size: CGFloat = 148

    @State private var rotation = 0.0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(0.18))
                .frame(width: size, height: size)
                .blur(radius: 20)
                .scaleEffect(pulse ? 1.14 : 0.94)

            Circle()
                .strokeBorder(
                    glowColor.opacity(0.22),
                    style: StrokeStyle(lineWidth: 1.4, dash: [4, 7])
                )
                .frame(width: size - 8, height: size - 8)
                .rotationEffect(.degrees(rotation))

            Circle()
                .strokeBorder(glowColor.opacity(0.16), lineWidth: 1.5)
                .frame(width: size - 32, height: size - 32)
                .rotationEffect(.degrees(-rotation * 0.55))

            switch mode {
            case .idle:
                AppIconTile(
                    systemName: "sparkles",
                    size: 76,
                    iconSize: 30,
                    cornerRadius: 38,
                    style: .accent
                )
            case .scanning(let progress):
                Circle()
                    .fill(AppColors.surface.opacity(0.92))
                    .frame(width: size - 48, height: size - 48)
                AppProgressRing(
                    progress: progress,
                    lineWidth: 8,
                    size: size - 52,
                    showsPercent: true
                )
                Circle()
                    .trim(from: 0, to: 0.16)
                    .stroke(
                        AppGradients.accentProgress,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                    )
                    .frame(width: size - 8, height: size - 8)
                    .rotationEffect(.degrees(rotation * 2.1))
            case .complete(let meaningful):
                AppIconTile(
                    systemName: meaningful ? "checkmark" : "sparkles",
                    size: 76,
                    iconSize: 28,
                    cornerRadius: 38,
                    style: meaningful ? .success : .accent
                )
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var glowColor: Color {
        switch mode {
        case .idle, .scanning:
            return AppColors.accent
        case .complete(let meaningful):
            return meaningful ? AppColors.success : AppColors.accent
        }
    }
}

struct SmartScanMetricChip: View {
    let icon: String
    let label: String
    var tint: Color = AppColors.accent

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

struct SmartScanSplitRing: View {
    var safeBytes: Int64
    var reviewBytes: Int64
    var appeared: Bool
    var size: CGFloat = 132

    private var total: Int64 { safeBytes + reviewBytes }

    private var safeFraction: Double {
        guard total > 0 else { return 0 }
        return Double(safeBytes) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.progressTrack, lineWidth: 14)

            if total > 0 {
                Circle()
                    .trim(from: 0, to: appeared ? max(safeArcEnd, 0.001) : 0)
                    .stroke(
                        AppColors.success,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                if safeFraction < 0.98 {
                    Circle()
                        .trim(from: appeared ? reviewArcStart : 1, to: appeared ? 1 : 1)
                        .stroke(
                            AppColors.warning,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }

            VStack(spacing: 2) {
                Text(ByteFormat.string(from: total))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                Text("recoverable")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.8, dampingFraction: 0.82), value: appeared)
    }

    private var gap: Double {
        (safeFraction > 0.04 && safeFraction < 0.96) ? 0.035 : 0
    }

    private var safeArcEnd: Double {
        max(0, safeFraction - gap / 2)
    }

    private var reviewArcStart: Double {
        min(1, safeFraction + gap / 2)
    }
}

private struct SmartScanAppear: ViewModifier {
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func smartScanAppear(delay: Double = 0) -> some View {
        modifier(SmartScanAppear(delay: delay))
    }
}

// MARK: - Scanning

struct SmartScanScanningCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    var body: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl, wash: {
            SmartScanHeroBackdrop()
        }) {
            HStack(alignment: .top, spacing: AppSpacing.xxl) {
                    VStack(spacing: AppSpacing.md) {
                        SmartScanOrb(mode: .scanning(session.progress), size: 148)

                        Text(session.progressLabel)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(width: 148)
                            .lineLimit(2)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        StatusBadge(
                            title: "Scanning · \(session.progressPercent)%",
                            style: .info,
                            icon: "dot.radiowaves.left.and.right"
                        )

                        Text(currentStageTitle)
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Checking caches, large files, duplicates, leftovers, and more.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)

                        AppProgressBar(progress: session.progress, height: 6)
                            .padding(.trailing, AppSpacing.sm)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm),
                            ],
                            spacing: AppSpacing.sm
                        ) {
                            ForEach(session.scanStages) { stage in
                                stageTile(stage)
                            }
                        }

                        SecondaryButton(title: "Cancel", icon: "xmark", size: .compact) {
                            appState.cancelSmartScan()
                        }
                    }

                    Spacer(minLength: 0)
                }
        }
    }

    private var currentStageTitle: String {
        session.scanStages.first(where: { $0.status == .running })?.title
            ?? "Scanning your Mac…"
    }

    private func stageTile(_ stage: SmartScanStage) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: stageIcon(stage.status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(stageColor(stage.status))
                .symbolEffect(.pulse, isActive: stage.status == .running)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(stage.title)
                    .font(AppTypography.calloutMedium)
                    .foregroundStyle(
                        stage.status == .pending ? AppColors.textTertiary : AppColors.textPrimary
                    )
                    .lineLimit(1)

                Text(stageCaption(stage))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if stage.status == .running {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(stageFill(stage.status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(
                    stage.status == .running ? AppColors.accent.opacity(0.35) : AppColors.borderSubtle,
                    lineWidth: 1
                )
        )
    }

    private func stageCaption(_ stage: SmartScanStage) -> String {
        if let detail = stage.detail, !detail.isEmpty { return detail }
        switch stage.status {
        case .pending: return "Waiting"
        case .running: return "In progress"
        case .completed: return "Done"
        case .failed: return "Couldn’t finish"
        case .skipped: return "Skipped"
        }
    }

    private func stageIcon(_ status: SmartScanStageStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .running: return "sparkle"
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

    private func stageFill(_ status: SmartScanStageStatus) -> Color {
        switch status {
        case .running: return AppColors.accentMuted
        case .completed: return AppColors.successMuted.opacity(0.55)
        case .failed: return AppColors.warningMuted
        default: return AppColors.surface.opacity(0.72)
        }
    }
}

// MARK: - Results hero

struct SmartScanResultHero: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    @State private var appeared = false
    @State private var checkPulse = false

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        AppCard(padding: AppSpacing.xxl, radius: AppRadius.xxxl, wash: {
            SmartScanHeroBackdrop(
                tint: summary.hasMeaningfulRecovery ? AppColors.success : AppColors.accent
            )
        }) {
            HStack(alignment: .center, spacing: AppSpacing.xl) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(
                                        (summary.hasMeaningfulRecovery ? AppColors.success : AppColors.accent)
                                            .opacity(0.16)
                                    )
                                    .frame(width: 28, height: 28)
                                    .scaleEffect(checkPulse ? 1.4 : 1)
                                    .opacity(checkPulse ? 0.2 : 0.7)

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
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(AppGradients.accentButton)
                                .monospacedDigit()

                            HStack(spacing: AppSpacing.sm) {
                                SmartScanMetricChip(
                                    icon: "tray.full",
                                    label: "\(summary.totalItemCount) items",
                                    tint: AppColors.accent
                                )
                                SmartScanMetricChip(
                                    icon: "checkmark.shield.fill",
                                    label: "\(summary.safeItemCount) safe",
                                    tint: AppColors.success
                                )
                                if summary.reviewItemCount > 0 {
                                    SmartScanMetricChip(
                                        icon: "eye.fill",
                                        label: "\(summary.reviewItemCount) to review",
                                        tint: AppColors.warning
                                    )
                                }
                            }
                            .padding(.top, AppSpacing.xxs)
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
                        VStack(spacing: AppSpacing.md) {
                            SmartScanSplitRing(
                                safeBytes: summary.safeToRemoveSize,
                                reviewBytes: summary.reviewRecommendedSize,
                                appeared: appeared
                            )

                            VStack(spacing: AppSpacing.xs) {
                                legendRow(
                                    color: AppColors.success,
                                    title: "Safe to remove",
                                    value: ByteFormat.string(from: summary.safeToRemoveSize)
                                )
                                legendRow(
                                    color: AppColors.warning,
                                    title: "Review recommended",
                                    value: ByteFormat.string(from: summary.reviewRecommendedSize)
                                )
                            }
                        }
                        .frame(width: 180)
                    } else {
                        SmartScanOrb(mode: .complete(false), size: 132)
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

    private func legendRow(color: Color, title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Junk CTA

struct SmartScanJunkCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore
    @EnvironmentObject private var scanResults: ScanResultsHub
    var isCleaning: Bool
    var onClean: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppGradients.icon(from: AppColors.success))
                    .frame(width: 52, height: 52)
                    .shadow(color: AppColors.success.opacity(0.32), radius: 10, x: 0, y: 4)
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    Text("Clean \(ByteFormat.string(from: scanResults.space.junkBytes)) of safe junk")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    StatusBadge(title: "Recommended", style: .success, icon: "star.fill")
                }
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
        .background {
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    LinearGradient(
                        colors: [AppColors.success.opacity(0.12), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
                }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColors.success)
                .frame(width: 4)
                .padding(.vertical, AppSpacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.success.opacity(0.24), lineWidth: 1)
        )
        .appShadow(AppShadow.card)
    }
}

// MARK: - Opportunities

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

    private var maxBytes: Int64 {
        max(filtered.map(\.bytes).max() ?? 1, 1)
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
                        .smartScanAppear(delay: 0.04 * Double(index))
                }
            }
        }
    }

    private func opportunityRow(_ item: SmartScanOpportunity, rank: Int) -> some View {
        let tint = item.destination?.tint ?? AppColors.accent
        let fraction = min(1, Double(item.bytes) / Double(maxBytes))

        return Button {
            if let destination = item.destination {
                appState.navigate(to: destination)
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack(alignment: .topLeading) {
                    AppIconTile(
                        systemName: item.destination?.systemImage ?? "sparkles",
                        size: 36,
                        iconSize: 14,
                        cornerRadius: AppRadius.md,
                        style: .tint(tint)
                    )
                    Text("\(rank)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(tint))
                        .offset(x: -5, y: -5)
                }
                .frame(width: 36, height: 36)
                .padding(.top, 2)
                .padding(.leading, 2)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(item.title)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        StatusBadge(title: item.safety.shortTitle, style: item.safety.badgeStyle)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(AppColors.progressTrack)
                            Capsule(style: .continuous)
                                .fill(AppGradients.icon(from: tint))
                                .frame(width: max(6, geo.size.width * fraction))
                        }
                    }
                    .frame(height: 5)
                }

                SizeBadge(value: item.sizeLabel, emphasis: .accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.surface)
                    .overlay {
                        LinearGradient(
                            colors: [tint.opacity(0.08), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                    }
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: 3)
                    .padding(.vertical, AppSpacing.sm)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .appHoverLift()
    }
}

// MARK: - Categories

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

    private var maxRecoverable: Int64 {
        max(visibleCategories.map(\.recoverableBytes).max() ?? 1, 1)
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
                    ForEach(Array(visibleCategories.enumerated()), id: \.element.id) { index, category in
                        categoryCard(category)
                            .smartScanAppear(delay: 0.05 * Double(index))
                    }
                }
            }
        }
    }

    private func categoryCard(_ category: SmartScanCategoryResult) -> some View {
        let tint = category.destination?.tint ?? AppColors.accent
        let fraction = min(1, Double(category.recoverableBytes) / Double(maxRecoverable))

        return Button {
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
                        style: .tint(tint)
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
                        Text("·")
                            .foregroundStyle(AppColors.textTertiary)
                        Text(category.id == "apps" ? "apps" : "\(category.itemCount) items")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Text(category.explanation)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .frame(minHeight: 32, alignment: .topLeading)
                }

                if category.id != "apps" {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(AppColors.progressTrack)
                            Capsule(style: .continuous)
                                .fill(AppGradients.icon(from: tint))
                                .frame(width: max(8, geo.size.width * max(fraction, 0.06)))
                        }
                    }
                    .frame(height: 4)
                }

                HStack(spacing: AppSpacing.xxs) {
                    Text("Review")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(tint)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                    Spacer(minLength: 0)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(AppColors.surface)
                    .overlay {
                        LinearGradient(
                            colors: [tint.opacity(0.12), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(tint.opacity(0.20), lineWidth: 1)
            )
            .appShadow(AppShadow.card)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
        .appHoverLift()
        .disabled(session.isScanning)
    }
}

// MARK: - Coverage

struct SmartScanCoverageCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    private var summary: SmartScanSummary { session.summary }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.accentMuted)
                    .frame(width: 36, height: 36)
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Coverage")
                    .font(AppTypography.calloutMedium)
                    .foregroundStyle(AppColors.textPrimary)

                if summary.coverageTitles.isEmpty {
                    Text("No authorized folders yet — apps still listed from /Applications.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                } else {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(Array(summary.coverageTitles.prefix(5).enumerated()), id: \.offset) { _, title in
                            Text(title)
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(AppColors.surface)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(AppColors.border, lineWidth: 1)
                                )
                        }
                        if summary.coverageTitles.count > 5 {
                            Text("+\(summary.coverageTitles.count - 5)")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
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
