//
//  ScanCoverageBanner.swift
//  mac_cleaner
//
//  Compact scan-limit notice — expanded details stay optional.
//

import SwiftUI

struct ScanCoverageBanner: View {
    let title: String
    let summary: String
    let notes: [String]
    var permissionsTitle: String = "Permissions"
    var rescanTitle: String? = "Rescan"
    var onPermissions: () -> Void
    var onRescan: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppTypography.calloutMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(summary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(isExpanded ? 3 : 1)
                }

                Spacer(minLength: AppSpacing.sm)

                if !notes.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Less" : "Details")
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                }

                SecondaryButton(title: permissionsTitle, size: .compact, action: onPermissions)

                if let rescanTitle, let onRescan {
                    SecondaryButton(title: rescanTitle, icon: "arrow.clockwise", size: .compact, action: onRescan)
                }
            }

            if isExpanded, !notes.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("•")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                            Text(note)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, AppSpacing.sm)
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.infoMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.info.opacity(0.18), lineWidth: 1)
        )
    }
}
