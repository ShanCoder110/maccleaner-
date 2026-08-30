//
//  SpaceResultsStore.swift
//  mac_cleaner
//

import Foundation
import Combine

@MainActor
final class SpaceResultsStore: ObservableObject {
    @Published var categories: [SpaceCategory] = []

    var junkItems: [StorageItem] {
        categories.flatMap(\.items).filter { $0.isSelected && !$0.isSensitive }
    }

    var junkBytes: Int64 { junkItems.reduce(0) { $0 + $1.byteSize } }
    var junkItemCount: Int { junkItems.count }
    var junkURLs: [URL] { junkItems.map(\.url) }

    func replace(_ categories: [SpaceCategory]) {
        self.categories = categories
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        for i in categories.indices {
            categories[i].items.removeAll { removedURLs.contains($0.url) }
        }
        categories.removeAll { $0.items.isEmpty }
    }
}
