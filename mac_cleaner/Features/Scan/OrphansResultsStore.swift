//
//  OrphansResultsStore.swift
//  mac_cleaner
//

import Foundation
import Combine

@MainActor
final class OrphansResultsStore: ObservableObject {
    @Published var items: [LeftoverItem] = []

    func replace(_ items: [LeftoverItem]) {
        self.items = items
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        items.removeAll { removedURLs.contains($0.url) }
    }
}
