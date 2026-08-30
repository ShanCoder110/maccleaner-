//
//  SizeBadge.swift
//  mac_cleaner
//

import SwiftUI

struct SizeBadge: View {
    let value: String
    var emphasis: Emphasis = .regular

    enum Emphasis {
        case regular
        case prominent
        case accent
    }

    var body: some View {
        Text(value)
            .font(AppTypography.monoCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs + 1)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous)
                    .strokeBorder(
                        emphasis == .accent ? AppColors.accent.opacity(0.22) : AppColors.borderSubtle,
                        lineWidth: 1
                    )
            )
    }

    private var foreground: Color {
        switch emphasis {
        case .regular: return AppColors.textSecondary
        case .prominent: return AppColors.textPrimary
        case .accent: return AppColors.accent
        }
    }

    private var background: Color {
        switch emphasis {
        case .regular: return AppColors.controlFillSecondary
        case .prominent: return AppColors.surfaceSecondary
        case .accent: return AppColors.accentMuted
        }
    }
}

