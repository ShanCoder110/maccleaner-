//
//  DuplicateFinderTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct DuplicateFinderTests {
    @Test func limitWarningsIncludeConfiguredCounts() {
        let result = DuplicateScanResult(
            groups: [],
            hitEntryLimit: true,
            hitGroupLimit: true,
            entryLimit: 60_000,
            groupLimit: 150
        )
        #expect(result.warnings.count == 2)
        #expect(result.warnings[0].contains("60,000") || result.warnings[0].contains("60000"))
        #expect(result.warnings[1].contains("150"))
    }

    @Test func groupLimitStopsAfterConfiguredCount() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-dupe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let a = Data(repeating: 3, count: 120_000)
        let b = Data(repeating: 9, count: 120_000)
        try writePair(named: "alpha", data: a, in: root)
        try writePair(named: "beta", data: b, in: root)

        let outcome = DuplicateFinder(entryLimitPerRoot: 100, groupLimit: 1)
            .findDuplicates(roots: [root])

        #expect(outcome.groups.count == 1)
        #expect(outcome.hitGroupLimit)
        #expect(outcome.groupLimit == 1)
        #expect(!outcome.warnings.isEmpty)
    }

    @Test func entryLimitIsConfigurable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-dupe-entries-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for i in 0..<4 {
            let url = root.appendingPathComponent("file-\(i).bin")
            try Data(repeating: UInt8(i), count: 8).write(to: url)
        }

        let outcome = DuplicateFinder(entryLimitPerRoot: 2, groupLimit: 10)
            .findDuplicates(roots: [root], minimumBytes: 1)

        #expect(outcome.hitEntryLimit)
        #expect(outcome.entryLimit == 2)
    }

    @Test func enforceAtLeastOneKeptBlocksSelectingEveryCopy() {
        let keep = DuplicateFile(
            url: URL(fileURLWithPath: "/Users/test/Documents/keep.jpg"),
            byteSize: 1_000,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified,
            isSelected: false,
            isRecommendedKeep: true
        )
        let extra = DuplicateFile(
            url: URL(fileURLWithPath: "/Users/test/Downloads/keep copy.jpg"),
            byteSize: 1_000,
            modified: Date(),
            created: Date(),
            hashState: .fullVerified,
            isSelected: true
        )
        var group = DuplicateGroup(
            byteSize: 1_000,
            files: [keep, extra],
            confidence: .confirmed,
            keepRecommendation: .recommended,
            keepID: keep.id
        )
        group.setFileSelected(fileID: keep.id, selected: true)
        #expect(group.files.contains { !$0.isSelected })
        #expect(!group.wouldDeleteAllIfCurrentSelection)
    }

    private func writePair(named name: String, data: Data, in root: URL) throws {
        try data.write(to: root.appendingPathComponent("\(name).bin"))
        try data.write(to: root.appendingPathComponent("\(name) copy.bin"))
    }
}
