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
            AppCanvasBackground()

            ScrollView(showsIndicators: true) {
                VStack(spacing: AppSpacing.xxl) {
                    header
                    permissionsCard
                        .frame(maxWidth: 560)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }

                    footerActions
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.vertical, AppSpacing.xxl)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                prompt(for: .caches)
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.md) {
            AppIconTile(
                systemName: "folder.badge.plus",
                size: 64,
                iconSize: 26,
                cornerRadius: AppRadius.xxl,
                style: .accent
            )

            Text("Welcome to \(AppLegal.displayName)")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("macOS will show a folder picker so you can grant access. Scan and clean only run in folders you approve. Grant Applications to uninstall apps to Trash.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520)
        }
    }

    private var permissionsCard: some View {
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
    }

    private var footerActions: some View {
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
        .padding(.bottom, AppSpacing.lg)
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
                AppIconTile(
                    systemName: "folder.badge.questionmark",
                    size: 36,
                    iconSize: 14,
                    cornerRadius: AppRadius.md,
                    style: .warning
                )
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
