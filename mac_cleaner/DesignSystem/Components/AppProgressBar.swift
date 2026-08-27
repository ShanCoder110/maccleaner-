//
//  AppProgressBar.swift
//  mac_cleaner
//

import SwiftUI

struct AppProgressBar: View {
    var progress: Double
    var height: CGFloat = 6
    var showsLabel: Bool = false
    var tint: Color = AppColors.accent

    var body: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(AppColors.progressTrack)

                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: max(height, geo.size.width * clampedProgress))
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
            }
            .frame(height: height)

            if showsLabel {
                Text("\(Int(clampedProgress * 100))%")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textTertiary)
                    .monospacedDigit()
            }
        }
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

struct AppProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 5
    var size: CGFloat = 44
    var tint: Color = AppColors.accent
    var showsPercent: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.progressTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            if showsPercent {
                Text("\(Int(clampedProgress * 100))")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

#Preview {
    VStack(spacing: 24) {
        AppProgressBar(progress: 0.62, showsLabel: true)
            .frame(width: 240)
        AppProgressRing(progress: 0.74)
    }
    .padding(40)
    .background(AppColors.background)
}
