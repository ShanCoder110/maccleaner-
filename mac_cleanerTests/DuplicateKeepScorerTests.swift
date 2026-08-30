//
//  DuplicateKeepScorerTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct DuplicateKeepScorerTests {
    @Test func prefersDocumentsOverDownloadsCopy() {
        let home = BookmarkStore.realUserHomePath()
        let documents = DuplicateFile(
            url: URL(fileURLWithPath: "\(home)/Documents/photo.jpg"),
            byteSize: 1_000_000,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified
        )
        let downloadsCopy = DuplicateFile(
            url: URL(fileURLWithPath: "\(home)/Downloads/photo copy.jpg"),
            byteSize: 1_000_000,
            modified: Date().addingTimeInterval(-86_400 * 40),
            created: Date().addingTimeInterval(-86_400 * 40),
            hashState: .fullVerified
        )

        let applied = DuplicateKeepScorer.applyRecommendation(to: [documents, downloadsCopy])

        #expect(applied.recommendation == .recommended)
        #expect(applied.keepID == documents.id)
        #expect(applied.files.first(where: { $0.id == documents.id })?.isSelected == false)
        #expect(applied.files.first(where: { $0.id == downloadsCopy.id })?.isSelected == true)
        #expect(applied.files.first(where: { $0.id == documents.id })?.isRecommendedKeep == true)
    }

    @Test func noClearRecommendationWhenScoresAreClose() {
        let home = BookmarkStore.realUserHomePath()
        let a = DuplicateFile(
            url: URL(fileURLWithPath: "\(home)/Documents/a.jpg"),
            byteSize: 100,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified
        )
        let b = DuplicateFile(
            url: URL(fileURLWithPath: "\(home)/Documents/b.jpg"),
            byteSize: 100,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified
        )

        let applied = DuplicateKeepScorer.applyRecommendation(to: [a, b])
        #expect(applied.recommendation == .noClearRecommendation)
        #expect(applied.files.allSatisfy { !$0.isSelected })
    }
}
