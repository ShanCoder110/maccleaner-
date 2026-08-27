//
//  IconButton.swift
//  mac_cleaner
//

import SwiftUI

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 13
    var isActive: Bool = false
    var help: String? = nil
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .strokeBorder(isActive ? AppColors.accent.opacity(0.25) : Color.clear, lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.94 : 1)
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help ?? "")
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
        if isActive { return AppColors.accent }
        return isHovered ? AppColors.textPrimary : AppColors.textSecondary
    }

    private var backgroundFill: Color {
        if isActive { return AppColors.accentMuted }
        return isHovered ? AppColors.surfaceHover : Color.clear
    }
}

