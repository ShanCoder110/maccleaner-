//
//  FolderAccessOnboardingView.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct FolderAccessOnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusMessage = ""
    @State private var didAutoPrompt = false

    private let presets: [GrantedFolder.Kind] = [
        .caches, .logs, .applicationSupport, .preferences, .downloads
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: AppSpacing.xxl) {
                VStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                            .fill(AppColors.accentMuted)
                            .frame(width: 72, height: 72)
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text("Welcome to MacCleaner+")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("macOS will show a folder picker so you can grant access. MacCleaner+ only scans and cleans inside folders you approve — plus apps you choose to uninstall.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }

                AppCard(radius: AppRadius.xxxl) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(presets, id: \.self) { kind in
                            presetRow(kind)
                        }

                        Divider().opacity(0.3)

                        HStack {
                            SecondaryButton(title: "Add Custom Folder", icon: "folder.badge.plus") {
                                prompt(for: .custom)
                            }
                            Spacer()
                            SecondaryButton(title: "AI Tool Folders", icon: "brain") {
                                prompt(for: .homeAI)
                            }
                        }

                        if !isGranted(.caches) {
                            PrimaryButton(
                                title: "Grant Caches Access Now",
                                icon: "hand.raised.fill"
                            ) {
                                prompt(for: .caches)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: 560)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: AppSpacing.md) {
                    SecondaryButton(title: "Skip for Now") {
                        appState.markOnboardingComplete()
                    }
                    PrimaryButton(
                        title: appState.bookmarks.hasAnyAccess ? "Continue" : "Continue Without Folders",
                        icon: "arrow.right"
                    ) {
                        appState.markOnboardingComplete()
                    }
                }
            }
            .padding(AppSpacing.xxxl)
        }
        .onAppear {
            // Automatically present the system folder permission picker once on launch.
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                prompt(for: .caches)
            }
        }
    }

    private func presetRow(_ kind: GrantedFolder.Kind) -> some View {
        let granted = isGranted(kind)
        return HStack(spacing: AppSpacing.md) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(BookmarkStore.suggestedPath(for: kind) ?? "Choose a folder")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if granted {
                StatusBadge(title: "Granted", style: .success, icon: "checkmark.circle.fill")
            } else {
                SecondaryButton(title: "Grant", size: .compact) {
                    prompt(for: kind)
                }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func isGranted(_ kind: GrantedFolder.Kind) -> Bool {
        appState.bookmarks.folders.contains { $0.kind == kind }
    }

    private func prompt(for kind: GrantedFolder.Kind) {
        // Ensure we are key window before presenting NSOpenPanel.
        NSApp.activate(ignoringOtherApps: true)
        if let folder = appState.bookmarks.ensurePresetAccess(kind: kind) {
            statusMessage = "Access granted for \(folder.kind.title)."
            appState.activityLog.log(.info, "Granted folder access: \(folder.kind.title)", path: folder.path)
        } else {
            statusMessage = "No folder was selected. You can grant access anytime."
        }
    }
}

struct FolderAccessBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if !appState.bookmarks.hasAnyAccess {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(AppColors.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Folder access required")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Grant access so the app can find files to clean. macOS will show a folder picker.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                SecondaryButton(title: "Grant Access", size: .compact) {
                    appState.showPermissionSetup = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NSApp.activate(ignoringOtherApps: true)
                        _ = appState.bookmarks.ensurePresetAccess(kind: .caches)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.warningMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(AppColors.warning.opacity(0.25), lineWidth: 1)
            )
        }
    }
}
