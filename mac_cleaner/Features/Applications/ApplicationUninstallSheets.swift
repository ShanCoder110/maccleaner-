//
//  ApplicationUninstallSheets.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct ApplicationUninstallConfirmSheet: View {
    @Bindable var model: ApplicationsViewModel

    var body: some View {
        let appsCount = model.selectedApps.count
        let relatedCount = max(0, model.selectedLeftoverItems.filter { $0.kind != .appBundle }.count)
        let total = model.selectedLeftoverItems.reduce(Int64(0)) { $0 + $1.byteSize }
        let sensitiveCount = model.selectedLeftoverItems.filter { $0.safety == .sensitive }.count
        let reviewCount = model.selectedLeftoverItems.filter { $0.safety == .reviewRecommended }.count
        let names = model.selectedApps.map(\.name).joined(separator: ", ")

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
                    model.showConfirmSheet = false
                }
                SecondaryButton(title: "Review Selection", size: .compact) {
                    model.showConfirmSheet = false
                }
                Spacer()
                PrimaryButton(title: "Move to Trash", icon: "trash", size: .compact) {
                    model.showConfirmSheet = false
                    Task { await model.uninstallSelected() }
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
}

struct ApplicationUninstallResultSheet: View {
    @Bindable var model: ApplicationsViewModel
    let result: UninstallResultSummary

    var body: some View {
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
                    model.showResultSheet = false
                    model.openActivity()
                }
                Spacer()
                PrimaryButton(title: "Done", size: .compact) {
                    model.showResultSheet = false
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(width: 480)
    }
}

struct ApplicationWhySheet: View {
    let item: LeftoverItem
    let onDismiss: () -> Void

    var body: some View {
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
                PrimaryButton(title: "Got it", size: .compact, action: onDismiss)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(width: 440)
    }
}
