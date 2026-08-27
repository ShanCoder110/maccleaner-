//
//  ContentView.swift
//  mac_cleaner
//

import SwiftUI

struct ContentView: View {
    @State private var selection: AppDestination = .smartScan

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selection: $selection)

            Group {
                switch selection {
                case .smartScan:
                    SmartScanView()
                case .applications:
                    ApplicationsView()
                case .designSystem:
                    DesignSystemGalleryView()
                case .junkFiles, .largeFiles, .duplicates:
                    PlaceholderDestinationView(destination: selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(AppColors.background)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
