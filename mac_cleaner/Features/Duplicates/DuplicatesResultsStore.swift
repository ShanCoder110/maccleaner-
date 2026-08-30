//
//  DuplicatesResultsStore.swift
//  mac_cleaner
//

import Foundation
import Combine

@MainActor
final class DuplicatesResultsStore: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var hitEntryLimit = false
    @Published var hitGroupLimit = false
    @Published var entryLimit = DuplicateFinder.defaultEntryLimitPerRoot
    @Published var groupLimit = DuplicateFinder.defaultGroupLimit

    var limitMessages: [String] {
        DuplicateScanLimits.warnings(
            hitEntryLimit: hitEntryLimit,
            hitGroupLimit: hitGroupLimit,
            entryLimit: entryLimit,
            groupLimit: groupLimit
        )
    }

    func replace(_ groups: [DuplicateGroup]) {
        self.groups = groups
    }

    func applyLimits(from outcome: DuplicateScanResult) {
        hitEntryLimit = outcome.hitEntryLimit
        hitGroupLimit = outcome.hitGroupLimit
        entryLimit = outcome.entryLimit
        groupLimit = outcome.groupLimit
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        for i in groups.indices {
            groups[i].files.removeAll { removedURLs.contains($0.url) }
            if groups[i].files.count >= 2 {
                groups[i].normalizeAfterMutation()
            }
        }
        groups.removeAll { $0.files.count < 2 }
    }
}
