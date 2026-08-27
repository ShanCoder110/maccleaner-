//
//  AppSidebar.swift
//  mac_cleaner
//

import SwiftUI

struct AppSidebar: View {
    @Binding var selection: AppDestination

    private let cleanGroup: [AppDestination] = [
        .smartScan, .applications, .junkFiles, .largeFiles, .duplicates
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    SidebarSectionLabel(title: "Clean")

                    ForEach(cleanGroup) { destination in
                        SidebarItem(
                            title: destination.title,
                            systemImage: destination.systemImage,
                            badge: destination.badge,
                            isSelected: selection == destination
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                selection = destination
                            }
                        }
                    }

                    SidebarSectionLabel(title: "Developer")
                        .padding(.top, AppSpacing.md)

                    SidebarItem(
                        title: AppDestination.designSystem.title,
                        systemImage: AppDestination.designSystem.systemImage,
                        isSelected: selection == .designSystem
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selection = .designSystem
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }

            Spacer(minLength: 0)

            footer
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
        }
        .frame(width: AppSpacing.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppColors.sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppColors.border)
                .frame(width: 1)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppColors.accent)
                    .frame(width: 30, height: 30)
                    .appShadow(AppShadow.button)

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Mac Cleaner")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Premium utility")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Reclaimable")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    SizeBadge(value: MockData.reclaimableTotal, emphasis: .accent)
                }

                AppProgressBar(progress: 0.68, height: 5)

                Text(MockData.lastScanLabel)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: AppDestination = .smartScan
    AppSidebar(selection: $selection)
        .frame(height: 640)
}
