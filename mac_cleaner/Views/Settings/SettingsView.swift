//
//  SettingsView.swift
//  mac_cleaner
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore
    @EnvironmentObject private var subscription: SubscriptionStore
    var showsToolbar: Bool = true
    @State private var showPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            if showsToolbar {
                ContentToolbar(
                    title: "Settings",
                    subtitle: "Appearance, permissions, and preferences",
                    searchText: .constant("")
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    appearanceCard
                    sensitivityCard
                    foldersCard
                    notesCard
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.contentInset)
                .padding(.vertical, AppSpacing.xl)
            }
        }
        .background(AppColors.background)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private var appearanceCard: some View {
        settingsSection(title: "Appearance") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Follows system appearance when set to System. Dark mode uses the built-in design tokens.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sensitivityCard: some View {
        settingsSection(title: "Related-file matching") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Matching", selection: sensitivityBinding) {
                    ForEach(LeftoverSensitivity.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(appState.sensitivity.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var foldersCard: some View {
        settingsSection(title: "Granted permissions") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Folder access uses the macOS folder picker. Grant Caches, Logs, or Application Support to enable scanning. Grant Applications to uninstall apps to Trash.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.sm) {
                    SecondaryButton(title: "Manage Permissions…", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }
                    Spacer(minLength: 0)
                }

                if bookmarks.folders.isEmpty {
                    Text("No folders granted yet.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, AppSpacing.xxs)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(bookmarks.folders) { folder in
                            folderRow(folder)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
        }
    }

    private func folderRow(_ folder: GrantedFolder) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: folder.kind.systemImage)
                .font(.system(size: 13, weight: .semibold))
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
                    .truncationMode(.middle)
            }

            Spacer(minLength: AppSpacing.sm)

            SecondaryButton(title: "Remove", size: .compact) {
                bookmarks.removeFolder(id: folder.id)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.controlFillSecondary)
        )
    }

    private var notesCard: some View {
        settingsSection(title: "About & legal") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("MacCleaner+ is a sandboxed storage manager. It does not claim to speed up your Mac, remove malware, or modify system files. Scanning and deletion only happen in folders you grant and for apps you explicitly uninstall.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.md) {
                    Button("Privacy Policy") {
                        showPrivacyPolicy = true
                    }
                    .buttonStyle(.plain)
                    Text("·")
                        .foregroundStyle(AppColors.textTertiary)
                    Link("Terms of Use", destination: AppLegal.termsOfUseURL)
                    Text("·")
                        .foregroundStyle(AppColors.textTertiary)
                    Link("Support", destination: AppLegal.supportMailtoURL)
                }
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.accent)

                SecondaryButton(title: "Restore Purchases", size: .compact) {
                    Task { await subscription.restore() }
                }

                #if DEBUG
                SecondaryButton(title: "Unlock Pro (Debug)", size: .compact) {
                    subscription.unlockProForDebug()
                }
                #endif

                if let error = subscription.purchaseError {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                }

                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        let sectionBody = content()
        return AppCard(padding: AppSpacing.xl, radius: AppRadius.xxl) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(title)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                sectionBody
            }
        }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { appState.appearanceMode },
            set: { appState.appearanceMode = $0 }
        )
    }

    private var sensitivityBinding: Binding<LeftoverSensitivity> {
        Binding(
            get: { appState.sensitivity },
            set: { appState.setSensitivity($0) }
        )
    }
}
