//
//  SidebarItem.swift
//  mac_cleaner
//

import SwiftUI

struct SidebarItem: View {
    let title: String
    let systemImage: String
    var badge: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(AppTypography.micro)
                        .foregroundStyle(isSelected ? AppColors.accent : AppColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? AppColors.accentMuted : AppColors.controlFillSecondary)
                        )
                }
            }
            .padding(.horizontal, AppSpacing.sm + 2)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundFill: Color {
        if isSelected { return AppColors.surfaceSelected }
        if isHovered { return AppColors.surfaceHover }
        return Color.clear
    }
}

struct SidebarSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.micro)
            .tracking(0.6)
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, AppSpacing.sm + 2)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

