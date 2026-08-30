//
//  AppIconTile.swift
//  mac_cleaner
//

import SwiftUI

/// Compact icon tile used for empty states, heroes, and sidebar branding.
struct AppIconTile: View {
    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 16
    var cornerRadius: CGFloat = AppRadius.md
    var style: Style = .accent

    enum Style {
        case accent
        case muted
        case success
        case warning
        case tint(Color)
    }

    var body: some View {
        ZStack {
            tileBackground
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var tileBackground: some View {
        switch style {
        case .accent:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppGradients.accentIcon)
                .appShadow(AppShadow.button)
        case .muted:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.accentMuted)
        case .success:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.successMuted)
        case .warning:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.warningMuted)
        case .tint(let color):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppGradients.icon(from: color))
                .shadow(color: color.opacity(0.32), radius: 8, x: 0, y: 3)
        }
    }

    private var iconColor: Color {
        switch style {
        case .accent, .tint: return .white
        case .muted: return AppColors.accent
        case .success: return AppColors.success
        case .warning: return AppColors.warning
        }
    }
}
