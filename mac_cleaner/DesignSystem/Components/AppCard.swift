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
                            .strokeBorder(AppGradients.cardEdge, lineWidth: 1)
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
                .appShadow(isSelected || isHovered ? AppShadow.card : AppShadow.soft)
                .scaleEffect(isHovered ? 1.008 : 1)
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

/// Light lift on hover for tappable rows that are not `SelectableAppCard`.
struct AppHoverLift: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.01 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func appHoverLift() -> some View {
        modifier(AppHoverLift())
    }
}
