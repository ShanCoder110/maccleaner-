//
//  ScanResultsHub.swift
//  mac_cleaner
//
//  Per-module scan arrays. ScanSessionStore holds progress and summaries only.
//

import Foundation
import Combine

@MainActor
final class ScanResultsHub: ObservableObject {
    let space: SpaceResultsStore
    let largeFiles: LargeFilesResultsStore
    let duplicates: DuplicatesResultsStore
    let orphans: OrphansResultsStore

    private var cancellables = Set<AnyCancellable>()

    init(
        space: SpaceResultsStore? = nil,
        largeFiles: LargeFilesResultsStore? = nil,
        duplicates: DuplicatesResultsStore? = nil,
        orphans: OrphansResultsStore? = nil
    ) {
        let spaceStore = space ?? SpaceResultsStore()
        let largeStore = largeFiles ?? LargeFilesResultsStore()
        let duplicatesStore = duplicates ?? DuplicatesResultsStore()
        let orphansStore = orphans ?? OrphansResultsStore()
        self.space = spaceStore
        self.largeFiles = largeStore
        self.duplicates = duplicatesStore
        self.orphans = orphansStore

        bind(spaceStore)
        bind(largeStore)
        bind(duplicatesStore)
        bind(orphansStore)
    }

    func replace(
        space: [SpaceCategory],
        large: [StorageItem],
        dupes: [DuplicateGroup],
        orphans: [LeftoverItem]
    ) {
        self.space.replace(space)
        largeFiles.replace(large, incomplete: false)
        duplicates.replace(dupes)
        self.orphans.replace(orphans)
    }

    func clearAfterClean(removedURLs: Set<URL>) {
        space.clearAfterClean(removedURLs: removedURLs)
        largeFiles.clearAfterClean(removedURLs: removedURLs)
        duplicates.clearAfterClean(removedURLs: removedURLs)
        orphans.clearAfterClean(removedURLs: removedURLs)
    }

    private func bind<T: ObservableObject>(_ store: T) {
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
