//
//  DestinationTint.swift
//  mac_cleaner
//

import SwiftUI

private struct DestinationTintKey: EnvironmentKey {
    static let defaultValue: Color = AppColors.accent
}

extension EnvironmentValues {
    var destinationTint: Color {
        get { self[DestinationTintKey.self] }
        set { self[DestinationTintKey.self] = newValue }
    }
}

extension View {
    func destinationTint(_ color: Color) -> some View {
        environment(\.destinationTint, color)
    }
}
