//
//  SectionHeader.swift
//  mac_cleaner
//

import SwiftUI

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.destinationTint) private var tint

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.sm) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppGradients.icon(from: tint))
                        .frame(width: 3, height: 16)

                    Text(title)
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColors.textPrimary)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer(minLength: AppSpacing.md)

            trailing()
        }
    }
}

