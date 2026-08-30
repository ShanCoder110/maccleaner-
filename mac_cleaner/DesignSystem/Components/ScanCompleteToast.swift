//
//  ScanCompleteToast.swift
//  mac_cleaner
//

import SwiftUI

struct ScanCompleteToast: View {
    let recoverableBytes: Int64
    let hasMeaningfulRecovery: Bool
    var onReview: (() -> Void)? = nil

    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulse ? 1.18 : 1)
                    .opacity(pulse ? 0.35 : 0.8)

                AppIconTile(
                    systemName: "checkmark",
                    size: 32,
                    iconSize: 13,
                    cornerRadius: 16,
                    style: .success
                )
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Scan complete")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(
                    hasMeaningfulRecovery
                        ? "\(ByteFormat.string(from: recoverableBytes)) ready to review"
                        : "You're all caught up"
                )
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            }

            if hasMeaningfulRecovery, let onReview {
                PrimaryButton(title: "Review", icon: "arrow.right", size: .compact, action: onReview)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.success.opacity(0.22), lineWidth: 1)
        )
        .appShadow(AppShadow.elevated)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.9).repeatCount(2, autoreverses: true)) {
                pulse = true
            }
        }
    }
}
