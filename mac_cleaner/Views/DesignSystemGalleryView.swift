//
//  DesignSystemGalleryView.swift
//  mac_cleaner
//

import SwiftUI

struct DesignSystemGalleryView: View {
    @State private var searchText = ""
    @State private var segment = "Buttons"
    @State private var checkboxA = true
    @State private var checkboxB = false
    @State private var progress: Double = 0.58

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Design System",
                subtitle: "Tokens and reusable components",
                searchText: $searchText,
                searchPlaceholder: "Filter components"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    AppSegmentedControl(
                        options: [
                            ("Buttons", "Buttons"),
                            ("Inputs", "Inputs"),
                            ("Feedback", "Feedback"),
                        ],
                        selection: $segment
                    )

                    buttonsSection
                    inputsSection
                    feedbackSection
                    emptySection
                }
                .padding(AppSpacing.contentInset)
            }
        }
        .background(AppColors.background)
    }

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Buttons", subtitle: "Primary, secondary, and icon actions")

            AppCard {
                HStack(spacing: AppSpacing.md) {
                    PrimaryButton(title: "Scan Now", icon: "magnifyingglass") {}
                    PrimaryButton(title: "Working…", isLoading: true) {}
                    SecondaryButton(title: "Cancel") {}
                    SecondaryButton(title: "Remove", icon: "trash", isDestructive: true) {}
                    IconButton(systemName: "sidebar.left") {}
                    IconButton(systemName: "ellipsis") {}
                    Spacer()
                }
            }
        }
    }

    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Inputs", subtitle: "Search and selection controls")

            AppCard {
                HStack(spacing: AppSpacing.xl) {
                    SearchField(text: $searchText, placeholder: "Search files…")
                        .frame(maxWidth: 280)

                    HStack(spacing: AppSpacing.md) {
                        SelectionCheckbox(isSelected: $checkboxA)
                        SelectionCheckbox(isSelected: $checkboxB)
                        SelectionCheckbox(isSelected: .constant(false), isIndeterminate: true)
                    }

                    Spacer()
                }
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Feedback", subtitle: "Badges and progress")

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(spacing: AppSpacing.sm) {
                        StatusBadge(title: "Safe", style: .success, icon: "checkmark.circle.fill")
                        StatusBadge(title: "Review", style: .warning, icon: "exclamationmark.triangle.fill")
                        StatusBadge(title: "Locked", style: .danger, icon: "lock.fill")
                        StatusBadge(title: "Scanning", style: .info, icon: "circle.dotted")
                        SizeBadge(value: "128 MB")
                        SizeBadge(value: "2.4 GB", emphasis: .accent)
                    }

                    HStack(spacing: AppSpacing.xl) {
                        AppProgressBar(progress: progress, showsLabel: true)
                            .frame(maxWidth: 280)
                        AppProgressRing(progress: progress)
                        SecondaryButton(title: "Animate", size: .compact) {
                            withAnimation {
                                progress = progress > 0.8 ? 0.2 : min(1, progress + 0.18)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Empty State")

            AppCard(padding: 0, radius: AppRadius.xxxl) {
                EmptyState(
                    title: "No leftovers found",
                    message: "This is a mock empty state used while the real uninstaller logic is still offline.",
                    systemImage: "checkmark.seal",
                    primaryActionTitle: "Run Scan",
                    primaryAction: {}
                )
                .frame(height: 280)
            }
        }
    }
}

#Preview {
    DesignSystemGalleryView()
        .frame(width: 860, height: 720)
}
