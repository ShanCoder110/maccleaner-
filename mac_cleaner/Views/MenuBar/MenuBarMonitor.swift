//
//  MenuBarMonitor.swift
//  mac_cleaner
//

import SwiftUI
import AppKit
import Combine

struct MenuBarMonitor: View {
    @EnvironmentObject private var appState: AppState
    @State private var snapshot = SystemStatsService.snapshot()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Storage Monitor")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.lg) {
                metric(title: "Disk Free", value: snapshot.diskFreeLabel, progress: snapshot.diskUsage)
                metric(title: "Memory", value: ByteFormat.string(from: snapshot.memoryUsedBytes), progress: snapshot.memoryUsage)
            }

            SecondaryButton(title: "Open Smart Scan", size: .compact) {
                appState.selection = .smartScan
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 280)
        .onAppear { snapshot = SystemStatsService.snapshot() }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            snapshot = SystemStatsService.snapshot()
        }
    }

    private func metric(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
            AppProgressBar(progress: min(max(progress, 0), 1), height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
