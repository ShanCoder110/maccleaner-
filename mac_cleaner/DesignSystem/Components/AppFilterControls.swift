//
//  AppFilterControls.swift
//  mac_cleaner
//
//  Custom filter chips and menu pickers that keep full labels at windowed widths.
//

import SwiftUI

/// Pill filter chips — labels never compress to “…”.
struct AppFilterChipGroup<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    @State private var hovered: T?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(options, id: \.0) { value, title in
                chip(value: value, title: title)
            }
        }
    }

    private func chip(value: T, title: String) -> some View {
        let isSelected = selection == value
        let isHovered = hovered == value

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selection = value
            }
        } label: {
            Text(title)
                .font(AppTypography.calloutMedium)
                .foregroundStyle(isSelected ? AppColors.textOnAccent : AppColors.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(AppGradients.accentButton) : AnyShapeStyle(isHovered ? AppColors.surfaceHover : AppColors.controlFill))
                )
                .appShadow(isSelected ? AppShadow.button : AppShadow.soft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hovered = hovering ? value : nil
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}

/// Styled menu picker matching MacCleaner+ controls (not system Picker chrome).
struct AppMenuPicker<T: Hashable>: View {
    var label: String? = nil
    let options: [(T, String)]
    @Binding var selection: T
    var minWidth: CGFloat = 120

    @State private var isHovered = false

    private var selectedTitle: String {
        options.first(where: { $0.0 == selection })?.1 ?? "—"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Visible custom chrome (Menu label is unreliable on macOS).
            HStack(spacing: AppSpacing.sm) {
                if let label {
                    Text(label)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(selectedTitle)
                    .font(AppTypography.calloutMedium)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: AppSpacing.xs)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 32)
            .frame(minWidth: minWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isHovered ? AppColors.controlFillHover : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(
                        isHovered ? AppColors.accent.opacity(0.45) : AppColors.borderStrong,
                        lineWidth: 1
                    )
            )

            // Invisible menu hit target over the chrome
            Menu {
                if let label {
                    Text(label)
                    Divider()
                }
                ForEach(options, id: \.0) { value, title in
                    Button {
                        selection = value
                    } label: {
                        if value == selection {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .frame(height: 32)
        .frame(minWidth: minWidth)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

