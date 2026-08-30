//
//  SettingsView.swift
//  mac_cleaner
//
//  Custom-designed settings — non-native UI with cards and visual polish.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore
    @EnvironmentObject private var subscription: SubscriptionStore
    var showsToolbar: Bool = true
    @State private var showPrivacyPolicy = false
    @State private var isRestoring = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsToolbar {
                ContentToolbar(
                    title: "Settings",
                    subtitle: "Personalize your MacCleaner+ experience",
                    searchText: .constant(""),
                    showsSearch: false,
                    showsAccessoryActions: false
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    membershipSection
                    appearanceSection
                    sensitivitySection
                    foldersSection
                    aboutSection
                }
                .frame(maxWidth: 740)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.contentInset)
                .padding(.vertical, AppSpacing.xl)
            }
        }
        .background(AppColors.background)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Membership

    private var membershipSection: some View {
        CustomSettingsSection(
            title: "Membership",
            icon: "crown.fill",
            gradient: subscription.isPro
                ? LinearGradient(colors: [Color(hex: 0xF59E0B), Color(hex: 0xEF4444)], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [AppColors.accent, AppColors.info], startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(subscription.isPro ? "Pro Member" : "Free Plan")
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                            
                            HStack(spacing: 3) {
                                Image(systemName: subscription.isPro ? "checkmark.seal.fill" : "circle")
                                    .font(.system(size: 9, weight: .bold))
                                Text(subscription.isPro ? "Active" : "Limited")
                                    .font(AppTypography.micro)
                            }
                            .foregroundStyle(subscription.isPro ? AppColors.success : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.sm - 1)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(subscription.isPro ? AppColors.successMuted : AppColors.surfaceSecondary)
                            )
                        }

                        Text(subscription.isPro
                            ? "All Pro features unlocked. Thanks for your support!"
                            : "Unlock Space Cleaner, Large Files, Space Lens & leftovers."
                        )
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    if !subscription.isPro {
                        PrimaryButton(title: "Upgrade", icon: "sparkles", size: .compact) {
                            appState.presentPaywall()
                        }
                    }
                }

                if subscription.isPro || subscription.purchaseError != nil {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if subscription.isPro {
                            SecondaryButton(
                                title: isRestoring ? "Restoring…" : "Restore Purchases",
                                icon: "arrow.clockwise",
                                size: .compact,
                                action: restorePurchases
                            )
                            .disabled(isRestoring)
                        }

                        if let error = subscription.purchaseError {
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.danger)
                        }
                    }
                }

                #if DEBUG
                SecondaryButton(title: "Unlock Pro (Debug)", icon: "lock.open.fill", size: .compact) {
                    subscription.unlockProForDebug()
                }
                #endif
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        CustomSettingsSection(
            title: "Appearance",
            icon: "paintbrush.fill",
            gradient: LinearGradient(
                colors: [Color(hex: 0x8B5CF6), Color(hex: 0x3B6FF5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(AppearanceMode.allCases) { mode in
                        SettingsOptionCard(
                            title: mode.title,
                            icon: mode.iconName,
                            isSelected: appState.appearanceMode == mode
                        ) {
                            appState.appearanceMode = mode
                        }
                    }
                }

                Text(appearanceHint)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.xs)
            }
        }
    }

    // MARK: - Sensitivity

    private var sensitivitySection: some View {
        CustomSettingsSection(
            title: "Leftover Matching",
            icon: "slider.horizontal.3",
            gradient: LinearGradient(
                colors: [Color(hex: 0x14B8A6), Color(hex: 0x10B981)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(LeftoverSensitivity.allCases) { sensitivity in
                        SettingsOptionCard(
                            title: sensitivity.title,
                            icon: sensitivity.iconName,
                            isSelected: appState.sensitivity == sensitivity,
                            isCompact: true
                        ) {
                            appState.setSensitivity(sensitivity)
                        }
                    }
                }

                Text(appState.sensitivity.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.xs)
            }
        }
    }

    // MARK: - Folders

    private var foldersSection: some View {
        CustomSettingsSection(
            title: "Folder Access",
            icon: "folder.badge.plus",
            gradient: LinearGradient(
                colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    PrimaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }

                    if !bookmarks.folders.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(bookmarks.folders.count) granted")
                                .font(AppTypography.micro)
                        }
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, AppSpacing.sm - 1)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.successMuted)
                        )
                    }

                    Spacer(minLength: 0)
                }

                if bookmarks.folders.isEmpty {
                    emptyFoldersState
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(bookmarks.folders) { folder in
                            customFolderRow(folder)
                        }
                    }
                }
            }
        }
    }

    private var emptyFoldersState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.surfaceSecondary)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("No folders granted")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Authorize folders to unlock scanning and cleanup")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColors.surfaceSecondary.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1, antialiased: true)
        )
    }

    private func customFolderRow(_ folder: GrantedFolder) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: folder.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.info],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

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

            Spacer()

            IconButton(systemName: "xmark.circle.fill", iconSize: 14, help: "Remove") {
                withAnimation(.spring(response: 0.3)) {
                    bookmarks.removeFolder(id: folder.id)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1, antialiased: true)
        )
    }

    // MARK: - About

    private var aboutSection: some View {
        CustomSettingsSection(
            title: "About",
            icon: "info.circle.fill",
            gradient: LinearGradient(
                colors: [AppColors.textSecondary, AppColors.textTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("MacCleaner+ is a sandboxed storage manager — not a speed booster or security tool.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    aboutLinkRow(title: "Privacy Policy", icon: "hand.raised.fill", isLast: false) {
                        showPrivacyPolicy = true
                    }
                    
                    Link(destination: AppLegal.termsOfUseURL) {
                        aboutLinkLabel(title: "Terms of Use", icon: "doc.text.fill", isLast: false)
                    }
                    .buttonStyle(.plain)

                    Link(destination: AppLegal.supportMailtoURL) {
                        aboutLinkLabel(title: "Support", icon: "envelope.fill", isLast: true)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text("Version \(appVersion)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
    }

    private func aboutLinkRow(title: String, icon: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            aboutLinkLabel(title: title, icon: icon, isLast: isLast)
        }
        .buttonStyle(.plain)
    }

    private func aboutLinkLabel(title: String, icon: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(AppColors.accentMuted)
                    )

                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: isLast ? 0 : AppRadius.sm, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())

            if !isLast {
                Rectangle()
                    .fill(AppColors.borderSubtle)
                    .frame(height: 1)
                    .padding(.leading, 52)
            }
        }
    }

    // MARK: - Helpers

    private var appearanceHint: String {
        switch appState.appearanceMode {
        case .system: return "Automatically matches your macOS system appearance"
        case .light: return "Always use light mode, regardless of system setting"
        case .dark: return "Always use dark mode, regardless of system setting"
        }
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            await subscription.restore()
            isRestoring = false
        }
    }
}

// MARK: - Custom Section

private struct CustomSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    gradient
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                        .appShadow(AppShadow.soft)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
            }

            content()
        }
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1, antialiased: true)
        )
        .appShadow(AppShadow.card)
    }
}

// MARK: - Option Card

private struct SettingsOptionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isCompact: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(height: isCompact ? 28 : 36)

                Text(title)
                    .font(isCompact ? AppTypography.captionMedium : AppTypography.calloutMedium)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? AppSpacing.md : AppSpacing.lg)
            .padding(.horizontal, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1, antialiased: true)
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundFill: Color {
        if isSelected { return AppColors.accentMuted }
        if isHovered { return AppColors.surfaceSecondary }
        return AppColors.surface
    }

    private var borderColor: Color {
        isSelected ? AppColors.accent : (isHovered ? AppColors.borderStrong : AppColors.border)
    }
}

// MARK: - Extensions

private extension AppearanceMode {
    var iconName: String {
        switch self {
        case .system: return "sparkles"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

private extension LeftoverSensitivity {
    var iconName: String {
        switch self {
        case .strict: return "shield.fill"
        case .enhanced: return "checkmark.shield.fill"
        case .deep: return "target"
        }
    }
}
