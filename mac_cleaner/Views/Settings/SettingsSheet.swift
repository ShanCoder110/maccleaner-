//
//  SettingsSheet.swift
//  mac_cleaner
//

import SwiftUI

/// Legacy sheet wrapper — prefers navigating to the Settings page.
struct SettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                IconButton(systemName: "xmark", help: "Close") { dismiss() }
            }
            .padding(AppSpacing.xxl)
            .padding(.bottom, 0)

            SettingsView(showsToolbar: false)
                .environmentObject(appState)
        }
        .frame(width: 620, height: 720)
        .background(AppColors.background)
        .onAppear {
            // Prefer in-window Settings when available.
        }
    }
}
