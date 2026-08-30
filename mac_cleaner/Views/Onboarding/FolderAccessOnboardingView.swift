//
//  FolderAccessOnboardingView.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct FolderAccessOnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore
    @State private var statusMessage = ""
    @State private var didAutoPrompt = false

    private let presets: [GrantedFolder.Kind] = [
        .caches, .logs, .applicationSupport, .developer, .containers, .preferences, .downloads
    ]

    /// Needed to move apps to Trash (sandbox cannot trash /Applications without a grant).
    private let appPresets: [GrantedFolder.Kind] = [
        .applicationsSystem, .applicationsUser
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

                    Text("macOS will show a folder picker so you can grant access. Scan and clean only run in folders you approve. Grant Applications to uninstall apps to Trash.")
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

                        ForEach(appPresets, id: \.self) { kind in
                            presetRow(kind, subtitle: appSubtitle(for: kind))
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
                        } else if !isGranted(.applicationsSystem) {
                            PrimaryButton(
                                title: "Grant Applications Access",
                                icon: "square.grid.2x2"
                            ) {
                                prompt(for: .applicationsSystem)
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
                        title: bookmarks.hasAnyAccess ? "Continue" : "Continue Without Folders",
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

    private func presetRow(_ kind: GrantedFolder.Kind, subtitle: String? = nil) -> some View {
        let granted = isGranted(kind)
        return HStack(spacing: AppSpacing.md) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle ?? BookmarkStore.suggestedPath(for: kind) ?? "Choose a folder")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
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

    private func appSubtitle(for kind: GrantedFolder.Kind) -> String {
        let path = BookmarkStore.suggestedPath(for: kind) ?? kind.title
        switch kind {
        case .applicationsSystem:
            return "\(path) — required to uninstall apps to Trash"
        case .applicationsUser:
            return "\(path) — optional, for apps installed in your user folder"
        default:
            return path
        }
    }

    private func isGranted(_ kind: GrantedFolder.Kind) -> Bool {
        bookmarks.folders.contains { $0.kind == kind }
    }

    private func prompt(for kind: GrantedFolder.Kind) {
        // Ensure we are key window before presenting NSOpenPanel.
        NSApp.activate(ignoringOtherApps: true)
        if let folder = bookmarks.ensurePresetAccess(kind: kind) {
            statusMessage = "Access granted for \(folder.kind.title)."
            appState.activityLog.log(.info, "Granted folder access: \(folder.kind.title)", path: folder.path)
        } else {
            statusMessage = "No folder was selected. You can grant access anytime."
        }
    }
}

struct FolderAccessBanner: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore

    var body: some View {
        if !bookmarks.hasAnyAccess {
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
                SecondaryButton(title: "Manage Permissions", size: .compact) {
                    appState.openManagePermissions()
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
