//
//  AppColors.swift
//  mac_cleaner
//
//  Semantic color tokens. Light values are primary; dark variants are defined
//  so appearance switching later requires no view-layer changes.
//

import SwiftUI
import AppKit

enum AppColors {
    // MARK: - Accent

    /// Fresh premium blue / indigo.
    static let accent = Color.dynamic(
        light: Color(hex: 0x3B6FF5),
        dark: Color(hex: 0x5B8AFF)
    )

    static let accentHover = Color.dynamic(
        light: Color(hex: 0x2F5FE0),
        dark: Color(hex: 0x6B96FF)
    )

    static let accentMuted = Color.dynamic(
        light: Color(hex: 0x3B6FF5).opacity(0.12),
        dark: Color(hex: 0x5B8AFF).opacity(0.18)
    )

    static let accentSubtle = Color.dynamic(
        light: Color(hex: 0x3B6FF5).opacity(0.06),
        dark: Color(hex: 0x5B8AFF).opacity(0.10)
    )

    // MARK: - Surfaces

    static let background = Color.dynamic(
        light: Color(hex: 0xF3F4F7),
        dark: Color(hex: 0x12141A)
    )

    static let sidebarBackground = Color.dynamic(
        light: Color(hex: 0xEBEDF2),
        dark: Color(hex: 0x0E1015)
    )

    static let surface = Color.dynamic(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x1A1C24)
    )

    static let surfaceSecondary = Color.dynamic(
        light: Color(hex: 0xF7F8FA),
        dark: Color(hex: 0x22252E)
    )

    static let surfaceElevated = Color.dynamic(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x23262F)
    )

    static let surfaceHover = Color.dynamic(
        light: Color(hex: 0x000000).opacity(0.035),
        dark: Color(hex: 0xFFFFFF).opacity(0.06)
    )

    static let surfaceSelected = Color.dynamic(
        light: Color(hex: 0x3B6FF5).opacity(0.10),
        dark: Color(hex: 0x5B8AFF).opacity(0.16)
    )

    // MARK: - Borders

    static let border = Color.dynamic(
        light: Color(hex: 0x000000).opacity(0.07),
        dark: Color(hex: 0xFFFFFF).opacity(0.09)
    )

    static let borderSubtle = Color.dynamic(
        light: Color(hex: 0x000000).opacity(0.045),
        dark: Color(hex: 0xFFFFFF).opacity(0.06)
    )

    static let borderStrong = Color.dynamic(
        light: Color(hex: 0x000000).opacity(0.12),
        dark: Color(hex: 0xFFFFFF).opacity(0.14)
    )

    // MARK: - Text

    static let textPrimary = Color.dynamic(
        light: Color(hex: 0x1A1D26),
        dark: Color(hex: 0xF2F3F7)
    )

    static let textSecondary = Color.dynamic(
        light: Color(hex: 0x5C6370),
        dark: Color(hex: 0xA0A6B4)
    )

    static let textTertiary = Color.dynamic(
        light: Color(hex: 0x8B929E),
        dark: Color(hex: 0x6F7684)
    )

    static let textOnAccent = Color.white

    // MARK: - Status

    static let success = Color.dynamic(
        light: Color(hex: 0x1F9D63),
        dark: Color(hex: 0x34C77B)
    )

    static let successMuted = Color.dynamic(
        light: Color(hex: 0x1F9D63).opacity(0.12),
        dark: Color(hex: 0x34C77B).opacity(0.18)
    )

    static let warning = Color.dynamic(
        light: Color(hex: 0xD97706),
        dark: Color(hex: 0xF0A03A)
    )

    static let warningMuted = Color.dynamic(
        light: Color(hex: 0xD97706).opacity(0.12),
        dark: Color(hex: 0xF0A03A).opacity(0.18)
    )

    static let danger = Color.dynamic(
        light: Color(hex: 0xDC3B3B),
        dark: Color(hex: 0xF25555)
    )

    static let dangerMuted = Color.dynamic(
        light: Color(hex: 0xDC3B3B).opacity(0.12),
        dark: Color(hex: 0xF25555).opacity(0.18)
    )

    static let info = accent
    static let infoMuted = accentMuted

    // MARK: - Controls

    static let controlFill = Color.dynamic(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x2A2D36)
    )

    static let controlFillSecondary = Color.dynamic(
        light: Color(hex: 0xF0F1F4),
        dark: Color(hex: 0x2F333D)
    )

    static let controlFillHover = Color.dynamic(
        light: Color(hex: 0xE8EAEE),
        dark: Color(hex: 0x383C47)
    )

    static let progressTrack = Color.dynamic(
        light: Color(hex: 0xE4E6EB),
        dark: Color(hex: 0x2F333D)
    )

    static let overlay = Color.dynamic(
        light: Color(hex: 0x000000).opacity(0.28),
        dark: Color(hex: 0x000000).opacity(0.45)
    )
}

// MARK: - Color Helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Appearance-aware color that resolves correctly under light and dark.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(
            nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(isDark ? dark : light)
            })
        )
    }
}
