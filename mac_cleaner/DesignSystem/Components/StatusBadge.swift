//
//  StatusBadge.swift
//  mac_cleaner
//

import SwiftUI

enum StatusBadgeStyle: Sendable {
    case success
    case warning
    case danger
    case info
    case neutral

    var foreground: Color {
        switch self {
        case .success: return AppColors.success
        case .warning: return AppColors.warning
        case .danger: return AppColors.danger
        case .info: return AppColors.info
        case .neutral: return AppColors.textSecondary
        }
    }

    var background: Color {
        switch self {
        case .success: return AppColors.successMuted
        case .warning: return AppColors.warningMuted
        case .danger: return AppColors.dangerMuted
        case .info: return AppColors.infoMuted
        case .neutral: return AppColors.controlFillSecondary
        }
    }
}

struct StatusBadge: View {
    let title: String
    var style: StatusBadgeStyle = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }

            Text(title)
                .font(AppTypography.captionMedium)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs + 1)
        .background(
            Capsule(style: .continuous)
                .fill(style.background)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(style.foreground.opacity(0.16), lineWidth: 1)
        )
    }
}

