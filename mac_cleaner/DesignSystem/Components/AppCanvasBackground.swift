//
//  AppCanvasBackground.swift
//  mac_cleaner
//

import SwiftUI

/// Soft ambient canvas used behind the main window so screens don't sit on flat gray.
struct AppCanvasBackground: View {
    var tint: Color = AppColors.accent

    var body: some View {
        ZStack {
            AppColors.background

            AppGradients.canvasWash(tint: tint)

            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: -220, y: -200)

            Circle()
                .fill(tint.opacity(0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 260, y: 240)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    func appCanvas(tint: Color = AppColors.accent) -> some View {
        background { AppCanvasBackground(tint: tint) }
    }
}
