//
//  PrimaryButton.swift
//  mac_cleaner
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var size: ButtonSize = .regular
    let action: () -> Void

    enum ButtonSize {
        case compact
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .compact: return 28
            case .regular: return 34
            case .large: return 40
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return 12
            case .regular: return 16
            case .large: return 20
            }
        }

        var font: Font {
            switch self {
            case .compact: return AppTypography.calloutMedium
            case .regular: return AppTypography.bodyMedium
            case .large: return AppTypography.headline
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact: return 11
            case .regular: return 12
            case .large: return 14
            }
        }
    }

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.textOnAccent)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundStyle(AppColors.textOnAccent)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(backgroundFill)
            )
            .appShadow(isDisabled || isLoading ? AppShadow.soft : AppShadow.button)
            .scaleEffect(isPressed && !isDisabled ? 0.98 : 1)
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
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
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var backgroundFill: Color {
        if isDisabled { return AppColors.accent.opacity(0.7) }
        return isHovered ? AppColors.accentHover : AppColors.accent
    }
}

