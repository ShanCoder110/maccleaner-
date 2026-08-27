//
//  PlaceholderDestinationView.swift
//  mac_cleaner
//

import SwiftUI

struct PlaceholderDestinationView: View {
    let destination: AppDestination
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: destination.title,
                subtitle: "UI placeholder · mock data only",
                searchText: $searchText
            )

            EmptyState(
                title: "\(destination.title) coming next",
                message: "The visual shell and design system are ready. This section will use the same cards, badges, and selection patterns.",
                systemImage: destination.systemImage
            )
        }
        .background(AppColors.background)
    }
}
