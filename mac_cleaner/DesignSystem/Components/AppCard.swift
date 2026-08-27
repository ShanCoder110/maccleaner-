//
//  AppCard.swift
//  mac_cleaner
//

import SwiftUI

struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.cardPadding
    var radius: CGFloat = AppRadius.card
    var showShadow: Bool = true
    var showBorder: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    }
                }
            )
            .appShadow(showShadow ? AppShadow.card : AppShadow.soft)
    }
}

/// Tappable card with hover + selection states for list / grid items.
struct SelectableAppCard<Content: View>: View {
    var isSelected: Bool = false
    var padding: CGFloat = AppSpacing.lg
    var radius: CGFloat = AppRadius.xl
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
                )
                .appShadow(AppShadow.soft)
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundFill: Color {
        if isSelected { return AppColors.surfaceSelected }
        if isHovered { return AppColors.surfaceSecondary }
        return AppColors.surface
    }

    private var borderColor: Color {
        isSelected ? AppColors.accent.opacity(0.35) : AppColors.border
    }
}

#Preview {
    VStack(spacing: 16) {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("System Junk")
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Caches, logs, and temporary files")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        SelectableAppCard(isSelected: true, action: {}) {
            Text("Selected item")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
    .padding(40)
    .frame(width: 360)
    .background(AppColors.background)
}
