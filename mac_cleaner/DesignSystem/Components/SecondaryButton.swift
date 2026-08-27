//
//  SecondaryButton.swift
//  mac_cleaner
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isDestructive: Bool = false
    var size: PrimaryButton.ButtonSize = .regular
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundStyle(foreground)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) { isPressed = false }
                }
        )
    }

    private var foreground: Color {
        isDestructive ? AppColors.danger : AppColors.textPrimary
    }

    private var backgroundFill: Color {
        if isHovered {
            return isDestructive ? AppColors.dangerMuted : AppColors.controlFillHover
        }
        return AppColors.controlFill
    }

    private var borderColor: Color {
        if isDestructive && isHovered {
            return AppColors.danger.opacity(0.25)
        }
        return AppColors.border
    }
}

#Preview {
    HStack(spacing: 12) {
        SecondaryButton(title: "Cancel") {}
        SecondaryButton(title: "Reveal", icon: "folder") {}
        SecondaryButton(title: "Remove", icon: "trash", isDestructive: true) {}
    }
    .padding(40)
    .background(AppColors.background)
}
