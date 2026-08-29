//
//  AppSidebar.swift
//  mac_cleaner
//

import SwiftUI

struct AppSidebar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: AppDestination
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.horizontal, AppSpacing.md)
                // Clearance for traffic lights when the title bar is transparent.
                .padding(.top, AppSpacing.xxxl)
                .padding(.bottom, AppSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    SidebarSectionLabel(title: "Storage")

                    ForEach(AppDestination.cleanGroup) { destination in
                        SidebarItem(
                            title: destination.title,
                            systemImage: destination.systemImage,
                            badge: destination.requiresPro && !appState.subscription.isPro ? "Pro" : nil,
                            isSelected: selection == destination
                        ) {
                            selection = destination
                        }
                    }

                    SidebarSectionLabel(title: "Tools")
                        .padding(.top, AppSpacing.md)

                    ForEach(AppDestination.toolsGroup) { destination in
                        SidebarItem(
                            title: destination.title,
                            systemImage: destination.systemImage,
                            isSelected: selection == destination
                        ) {
                            selection = destination
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }

            Spacer(minLength: AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                upgradeCard
                diskFooter
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
        }
        .frame(width: AppSpacing.sidebarWidth)
        .frame(maxHeight: .infinity)
        // Extend under the transparent title bar so the top matches the theme.
        .background(AppColors.sidebarBackground.ignoresSafeArea(edges: .top))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppColors.border)
                .frame(width: 1)
                .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            DispatchQueue.main.async {
                appState.refreshDiskStats()
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppColors.accent)
                    .frame(width: 30, height: 30)
                    .appShadow(AppShadow.button)

                Image(systemName: "internaldrive")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("MacCleaner+")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Clean smarter")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer(minLength: 0)

            IconButton(systemName: "gearshape", size: 28, iconSize: 12, help: "Settings", action: onOpenSettings)
        }
    }

    private var upgradeCard: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: appState.subscription.isPro ? "crown.fill" : "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                    Text(appState.subscription.isPro ? "Pro" : "Upgrade to Pro")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    StatusBadge(
                        title: appState.subscription.isPro ? "Active" : "Free",
                        style: appState.subscription.isPro ? .success : .neutral
                    )
                }

                Text(appState.subscription.isPro
                     ? appState.subscription.statusLabel
                     : "Unlock Space Cleaner, Large Files, Space Lens & more.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                if appState.subscription.isPro {
                    SecondaryButton(title: "Manage", size: .compact) {
                        selection = .settings
                    }
                } else {
                    PrimaryButton(title: "Upgrade to Pro", icon: "sparkles", size: .compact) {
                        appState.presentPaywall()
                    }
                }
            }
        }
    }

    private var diskFooter: some View {
        Button {
            appState.openManagePermissions()
        } label: {
            AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text("Folders")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                        Spacer()
                        SizeBadge(
                            value: "\(appState.bookmarks.folders.count)",
                            emphasis: appState.bookmarks.hasAnyAccess ? .accent : .regular
                        )
                    }

                    AppProgressBar(progress: appState.diskUsage, height: 5)

                    Text(appState.bookmarks.hasAnyAccess
                         ? "\(appState.diskFreeLabel) free · Permissions"
                         : "\(appState.diskFreeLabel) free · Grant permissions")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
