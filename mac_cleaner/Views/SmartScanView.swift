//
//  SmartScanView.swift
//  mac_cleaner
//

import SwiftUI

struct SmartScanView: View {
    @State private var searchText = ""
    @State private var scanProgress: Double = 0.74

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Smart Scan",
                subtitle: "Mock overview of reclaimable space",
                searchText: $searchText,
                searchPlaceholder: "Search categories"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    heroCard
                    categoriesGrid
                }
                .padding(AppSpacing.contentInset)
            }
        }
        .background(AppColors.background)
    }

    private var heroCard: some View {
        AppCard(radius: AppRadius.xxxl) {
            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                AppProgressRing(progress: scanProgress, lineWidth: 6, size: 72)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    StatusBadge(title: "Scan complete", style: .success, icon: "checkmark.circle.fill")

                    Text("\(MockData.reclaimableTotal) can be cleaned")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Dummy results across caches, leftovers, and large files. No real scanning is performed yet.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppSpacing.sm) {
                        PrimaryButton(title: "Review Items", icon: "list.bullet.rectangle") {}
                        SecondaryButton(title: "Scan Again", icon: "arrow.clockwise") {}
                    }
                    .padding(.top, AppSpacing.xs)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Categories", subtitle: "Tap any card to explore mock details")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md),
                ],
                spacing: AppSpacing.md
            ) {
                ForEach(MockData.junkCategories) { category in
                    junkCategoryCard(category)
                }
            }
        }
    }

    private func junkCategoryCard(_ category: MockJunkCategory) -> some View {
        AppCard(padding: AppSpacing.lg, radius: AppRadius.xxl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(AppColors.accentMuted)
                            .frame(width: 36, height: 36)

                        Image(systemName: category.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                    }

                    Spacer()
                    SizeBadge(value: category.sizeLabel, emphasis: .prominent)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(category.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(category.subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                AppProgressBar(progress: category.progress, height: 4)

                Text("\(category.itemCount) items")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    SmartScanView()
        .frame(width: 780, height: 640)
}
