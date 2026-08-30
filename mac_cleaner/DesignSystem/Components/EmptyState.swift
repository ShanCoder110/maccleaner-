//
//  EmptyState.swift
//  mac_cleaner
//

import SwiftUI

struct EmptyState: View {
    let title: String
    var message: String? = nil
    var systemImage: String = "tray"
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    @Environment(\.destinationTint) private var tint

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 108, height: 108)
                    .blur(radius: 12)

                AppIconTile(
                    systemName: systemImage,
                    size: 72,
                    iconSize: 28,
                    cornerRadius: AppRadius.xxl,
                    style: .tint(tint)
                )
            }

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            if primaryActionTitle != nil || secondaryActionTitle != nil {
                HStack(spacing: AppSpacing.sm) {
                    if let secondaryActionTitle, let secondaryAction {
                        SecondaryButton(title: secondaryActionTitle, action: secondaryAction)
                    }
                    if let primaryActionTitle, let primaryAction {
                        PrimaryButton(title: primaryActionTitle, action: primaryAction)
                    }
                }
                .padding(.top, AppSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xxxl)
    }
}

