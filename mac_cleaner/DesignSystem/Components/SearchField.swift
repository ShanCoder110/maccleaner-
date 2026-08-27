//
//  SearchField.swift
//  mac_cleaner
//

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused ? AppColors.accent : AppColors.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isFocused)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .fill(AppColors.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
        )
        .appShadow(isFocused ? AppShadow.soft : AppShadow.soft)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var borderColor: Color {
        if isFocused { return AppColors.accent.opacity(0.55) }
        if isHovered { return AppColors.borderStrong }
        return AppColors.border
    }
}

