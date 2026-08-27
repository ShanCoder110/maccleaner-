//
//  AppSegmentedControl.swift
//  mac_cleaner
//

import SwiftUI

struct AppSegmentedControl<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    @Namespace private var segmentNamespace
    @State private var hoveredOption: T?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                segment(value: value, title: title)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.controlFillSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segment(value: T, title: String) -> some View {
        let isSelected = selection == value
        let isHovered = hoveredOption == value

        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selection = value
            }
        } label: {
            Text(title)
                .font(AppTypography.calloutMedium)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 28)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppRadius.md - 1, style: .continuous)
                            .fill(AppColors.surface)
                            .appShadow(AppShadow.soft)
                            .matchedGeometryEffect(id: "segmentSelection", in: segmentNamespace)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: AppRadius.md - 1, style: .continuous)
                            .fill(AppColors.surfaceHover)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: AppRadius.md - 1, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredOption = hovering ? value : nil
            }
        }
    }
}

#Preview {
    @Previewable @State var tab = "All"
    AppSegmentedControl(
        options: [("All", "All"), ("Selected", "Selected"), ("Large", "Large")],
        selection: $tab
    )
    .padding(40)
    .background(AppColors.background)
}
