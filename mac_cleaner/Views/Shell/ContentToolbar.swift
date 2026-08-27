//
//  ContentToolbar.swift
//  mac_cleaner
//

import SwiftUI

struct ContentToolbar: View {
    let title: String
    var subtitle: String? = nil
    @Binding var searchText: String
    var searchPlaceholder: String = "Search"

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer(minLength: AppSpacing.lg)

            SearchField(text: $searchText, placeholder: searchPlaceholder)
                .frame(width: 240)

            IconButton(systemName: "arrow.clockwise", help: "Refresh") {}
            IconButton(systemName: "gearshape", help: "Settings") {}
        }
        .padding(.horizontal, AppSpacing.contentInset)
        .padding(.vertical, AppSpacing.lg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.borderSubtle)
                .frame(height: 1)
        }
    }
}
