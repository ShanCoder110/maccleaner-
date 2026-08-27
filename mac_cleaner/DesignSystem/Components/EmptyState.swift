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

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(AppColors.accentSubtle)
                    .frame(width: 72, height: 72)

                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .symbolRenderingMode(.hierarchical)
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

