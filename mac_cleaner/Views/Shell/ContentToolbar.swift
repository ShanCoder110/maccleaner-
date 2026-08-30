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
    var showsSearch: Bool = true

    @EnvironmentObject private var appState: AppState
    @Environment(\.destinationTint) private var tint

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            AppIconTile(
                systemName: appState.selection.systemImage,
                size: 32,
                iconSize: 14,
                cornerRadius: 9,
                style: .tint(tint)
            )

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

            if showsSearch {
                SearchField(text: $searchText, placeholder: searchPlaceholder)
                    .frame(width: 240)
            }
        }
        .padding(.horizontal, AppSpacing.contentInset)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.borderSubtle)
                .frame(height: 1)
        }
    }
}
