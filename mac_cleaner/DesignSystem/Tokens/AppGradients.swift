//
//  AppGradients.swift
//  mac_cleaner
//
//  Shared gradient tokens so polish stays consistent across screens.
//

import SwiftUI

enum AppGradients {
    static let accentButton = LinearGradient(
        colors: [Color(hex: 0x5B8AFF), Color(hex: 0x3B6FF5)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentButtonHover = LinearGradient(
        colors: [Color(hex: 0x6B96FF), Color(hex: 0x2F5FE0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentButtonDisabled = LinearGradient(
        colors: [Color(hex: 0x3B6FF5).opacity(0.72), Color(hex: 0x3B6FF5).opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentIcon = LinearGradient(
        colors: [Color(hex: 0x6B96FF), Color(hex: 0x355FE8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentProgress = LinearGradient(
        colors: [Color(hex: 0x6B96FF), AppColors.accent],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let canvasWash = LinearGradient(
        colors: [
            AppColors.accent.opacity(0.07),
            Color.clear,
            Color(hex: 0x8B5CF6).opacity(0.045)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarWash = LinearGradient(
        colors: [
            AppColors.accent.opacity(0.05),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .center
    )

    static let cardSheen = LinearGradient(
        colors: [
            Color.dynamic(light: Color.white.opacity(0.7), dark: Color.white.opacity(0.07)),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .center
    )

    static let cardEdge = LinearGradient(
        colors: [
            Color.dynamic(light: Color.white.opacity(0.95), dark: Color.white.opacity(0.16)),
            AppColors.border,
            AppColors.border.opacity(0.75)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let upgradeWash = LinearGradient(
        colors: [
            AppColors.accentMuted,
            AppColors.surface
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func icon(from color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.78), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func canvasWash(tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(0.08),
                Color.clear,
                tint.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
