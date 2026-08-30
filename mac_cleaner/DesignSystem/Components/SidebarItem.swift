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
    var tint: Color = AppColors.accent
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(AppGradients.icon(from: tint)) : AnyShapeStyle(Color.clear))
                        .frame(width: 22, height: 22)

                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : AppColors.textSecondary)
                }
                .frame(width: 22, height: 22)

                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(AppTypography.micro)
                        .foregroundStyle(isSelected ? tint : AppColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? tint.opacity(0.14) : AppColors.controlFillSecondary)
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
        if isSelected { return tint.opacity(0.12) }
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

