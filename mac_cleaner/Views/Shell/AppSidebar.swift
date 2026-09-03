//
//  AppSidebar.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct AppSidebar: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscription: SubscriptionStore
    @EnvironmentObject private var bookmarks: BookmarkStore
    @Binding var selection: AppDestination

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
                            badge: destination.requiresPro && !subscription.isPro ? "Pro" : nil,
                            isSelected: selection == destination,
                            tint: destination.tint
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
                            isSelected: selection == destination,
                            tint: destination.tint
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
        .background {
            ZStack {
                AppColors.sidebarBackground
                AppGradients.sidebarWash
            }
            .ignoresSafeArea(edges: .top)
        }
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
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppLegal.shortName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Clean Smarter")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var upgradeCard: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    AppIconTile(
                        systemName: "crown.fill",
                        size: 22,
                        iconSize: 10,
                        cornerRadius: 7,
                        style: .accent
                    )
                    Text(subscription.isPro ? "Pro" : "Upgrade to Pro")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    StatusBadge(
                        title: subscription.isPro ? "Active" : "Free",
                        style: subscription.isPro ? .success : .neutral
                    )
                }

                Text(subscription.isPro
                     ? subscription.statusLabel
                     : "Unlock Space Cleaner, Large Files, Space Lens & more.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                if subscription.isPro {
                    SecondaryButton(title: "Manage", size: .compact) {
                        appState.presentPaywall()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    PrimaryButton(title: "Upgrade to Pro", icon: "crown.fill", size: .compact) {
                        appState.presentPaywall()
                    }
                    .frame(maxWidth: .infinity)
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
                            value: "\(bookmarks.folders.count)",
                            emphasis: bookmarks.hasAnyAccess ? .accent : .regular
                        )
                    }

                    AppProgressBar(progress: appState.diskUsage, height: 5)

                    Text(bookmarks.hasAnyAccess
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
