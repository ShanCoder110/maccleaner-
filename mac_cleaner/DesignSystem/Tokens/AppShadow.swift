//
//  AppShadow.swift
//  mac_cleaner
//

import SwiftUI

enum AppShadow {
    struct Style {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Soft elevation for cards on the canvas.
    static let card = Style(
        color: Color.black.opacity(0.045),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Slightly stronger lift for floating panels / popovers.
    static let elevated = Style(
        color: Color.black.opacity(0.08),
        radius: 20,
        x: 0,
        y: 8
    )

    /// Subtle depth under primary buttons.
    static let button = Style(
        color: Color(hex: 0x3B6FF5).opacity(0.28),
        radius: 10,
        x: 0,
        y: 4
    )

    /// Near-invisible edge definition.
    static let soft = Style(
        color: Color.black.opacity(0.03),
        radius: 6,
        x: 0,
        y: 2
    )
}

extension View {
    func appShadow(_ style: AppShadow.Style) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
