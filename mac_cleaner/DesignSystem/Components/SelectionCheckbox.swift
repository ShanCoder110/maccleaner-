//
//  SelectionCheckbox.swift
//  mac_cleaner
//

import SwiftUI

struct SelectionCheckbox: View {
    @Binding var isSelected: Bool
    var size: CGFloat = 18
    var isIndeterminate: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isSelected.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.xs - 1, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xs - 1, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: 1.25)
                    )
                    .frame(width: size, height: size)
                    .appShadow(isSelected || isIndeterminate ? AppShadow.button : AppShadow.soft)

                if isIndeterminate {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(AppColors.textOnAccent)
                        .frame(width: size * 0.45, height: 2)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(AppColors.textOnAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isIndeterminate ? "Mixed" : (isSelected ? "Selected" : "Not selected"))
    }

    private var fillColor: Color {
        if isSelected || isIndeterminate {
            return isHovered ? AppColors.accentHover : AppColors.accent
        }
        return isHovered ? AppColors.controlFillHover : AppColors.controlFill
    }

    private var strokeColor: Color {
        if isSelected || isIndeterminate {
            return AppColors.accent.opacity(0.35)
        }
        return isHovered ? AppColors.borderStrong : AppColors.border
    }
}

#Preview {
    @Previewable @State var a = true
    @Previewable @State var b = false
    HStack(spacing: 16) {
        SelectionCheckbox(isSelected: $a)
        SelectionCheckbox(isSelected: $b)
        SelectionCheckbox(isSelected: .constant(false), isIndeterminate: true)
    }
    .padding(40)
    .background(AppColors.background)
}
