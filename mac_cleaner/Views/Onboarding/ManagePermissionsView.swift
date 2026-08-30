//
//  ManagePermissionsView.swift
//  mac_cleaner
//
//  In-app folder permission manager (not first-run onboarding).
//

import SwiftUI
import AppKit

struct ManagePermissionsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore
    @Environment(\.dismiss) private var dismiss
    @State private var statusMessage = ""

    private let scanPresets: [GrantedFolder.Kind] = [
        .caches, .logs, .applicationSupport, .developer, .containers, .preferences, .downloads
    ]

    private let appPresets: [GrantedFolder.Kind] = [
        .applicationsSystem, .applicationsUser
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    grantSection(
                        title: "Scan locations",
                        subtitle: "Caches, logs, and other folders used by Smart Scan and cleanup.",
                        kinds: scanPresets
                    )

                    grantSection(
                        title: "Applications",
                        subtitle: "Required to move apps to Trash when uninstalling.",
                        kinds: appPresets,
                        useAppSubtitles: true
                    )

                    extrasSection

                    if !bookmarks.folders.isEmpty {
                        grantedSection
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.xl)
            }

            Divider().opacity(0.35)
            HStack {
                Spacer()
                PrimaryButton(title: "Done", icon: "checkmark") {
                    dismiss()
                }
            }
            .padding(AppSpacing.lg)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 480, idealHeight: 560)
        .background(AppColors.background)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.accentMuted)
                    .frame(width: 40, height: 40)
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Manage Permissions")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("MacCleaner+ only scans and cleans inside folders you authorize.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
    }

    private func grantSection(
        title: String,
        subtitle: String,
        kinds: [GrantedFolder.Kind],
        useAppSubtitles: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)

            AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(kinds, id: \.self) { kind in
                        presetRow(
                            kind,
                            subtitle: useAppSubtitles ? appSubtitle(for: kind) : nil
                        )
                    }
                }
            }
        }
    }

    private var extrasSection: some View {
        HStack(spacing: AppSpacing.sm) {
            SecondaryButton(title: "Add Custom Folder", icon: "folder.badge.plus") {
                prompt(for: .custom)
            }
            SecondaryButton(title: "AI Tool Folders", icon: "brain") {
                prompt(for: .homeAI)
            }
            Spacer(minLength: 0)
        }
    }

    private var grantedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Currently granted")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)

            AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(bookmarks.folders) { folder in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: folder.kind.systemImage)
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.displayName)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(folder.path)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            SecondaryButton(title: "Revoke", size: .compact) {
                                bookmarks.removeFolder(id: folder.id)
                                statusMessage = "Revoked access to \(folder.displayName)."
                                appState.activityLog.log(.info, "Revoked folder access", path: folder.path)
                            }
                        }
                    }
                }
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
            return "\(path) — optional, for apps in your user folder"
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
            statusMessage = "No folder was selected."
        }
    }
}
