//
//  PrivacyPolicyView.swift
//  mac_cleaner
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(AppLegal.privacyPolicyTitle)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                IconButton(systemName: "xmark", size: 28, iconSize: 11, help: "Close") {
                    dismiss()
                }
            }

            ScrollView {
                Text(AppLegal.privacyPolicyText)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let url = AppLegal.hostedPrivacyPolicyURL {
                Link("Open hosted privacy page", destination: url)
                    .font(AppTypography.captionMedium)
            }
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 420, idealHeight: 520)
        .background(AppColors.background)
    }
}
