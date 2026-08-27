//
//  ApplicationsView.swift
//  mac_cleaner
//

import SwiftUI

struct ApplicationsView: View {
    @State private var searchText = ""
    @State private var filter: String = "All"
    @State private var items = MockData.applications

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Applications",
                subtitle: "Select apps to review leftover files",
                searchText: $searchText,
                searchPlaceholder: "Search applications"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    AppSegmentedControl(
                        options: [("All", "All"), ("Selected", "Selected"), ("Large", "Large")],
                        selection: $filter
                    )

                    Spacer()

                    SecondaryButton(title: "Deselect All", size: .compact) {
                        for index in items.indices {
                            items[index].isSelected = false
                        }
                    }

                    PrimaryButton(title: "Uninstall", icon: "trash", size: .compact) {}
                }

                SectionHeader(
                    title: "Installed Apps",
                    subtitle: "\(selectedCount) selected · mock data only"
                ) {
                    SizeBadge(value: "3.8 GB", emphasis: .accent)
                }

                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach($items) { $item in
                            applicationRow(item: $item)
                        }
                    }
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(AppColors.background)
    }

    private var selectedCount: Int {
        items.filter(\.isSelected).count
    }

    private func applicationRow(item: Binding<MockAppItem>) -> some View {
        SelectableAppCard(isSelected: item.wrappedValue.isSelected) {
            item.wrappedValue.isSelected.toggle()
        } content: {
            HStack(spacing: AppSpacing.md) {
                SelectionCheckbox(isSelected: item.isSelected)

                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.surfaceSecondary)
                        .frame(width: 40, height: 40)

                    Text(String(item.wrappedValue.name.prefix(1)))
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.wrappedValue.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(item.wrappedValue.category) · \(item.wrappedValue.leftoverCount) leftovers")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                StatusBadge(title: statusTitle(item.wrappedValue.status), style: item.wrappedValue.status)
                SizeBadge(value: item.wrappedValue.sizeLabel, emphasis: .prominent)
            }
        }
    }

    private func statusTitle(_ style: StatusBadgeStyle) -> String {
        switch style {
        case .success: return "Clean"
        case .warning: return "Review"
        case .danger: return "Heavy"
        case .info: return "Active"
        case .neutral: return "Idle"
        }
    }
}

#Preview {
    ApplicationsView()
        .frame(width: 820, height: 640)
}
