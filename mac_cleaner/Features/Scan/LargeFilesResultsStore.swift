//
//  LargeFilesResultsStore.swift
//  mac_cleaner
//

import Foundation
import Combine

@MainActor
final class LargeFilesResultsStore: ObservableObject {
    @Published var items: [StorageItem] = []
    @Published var scanIncomplete = false
    @Published var itemLimit = 300

    var incompleteMessage: String? {
        guard scanIncomplete else { return nil }
        return LargeFilesScanResult(
            items: items,
            incomplete: true,
            itemLimit: itemLimit,
            fileCap: DirectoryWalk.defaultFileCap
        ).warning
    }

    func replace(_ items: [StorageItem], incomplete: Bool = false, itemLimit: Int = 300) {
        self.items = items
        self.scanIncomplete = incomplete
        self.itemLimit = itemLimit
    }

    func apply(_ result: LargeFilesScanResult) {
        replace(result.items, incomplete: result.incomplete, itemLimit: result.itemLimit)
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        items.removeAll { removedURLs.contains($0.url) }
    }
}
