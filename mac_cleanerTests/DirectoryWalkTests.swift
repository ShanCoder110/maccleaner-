//
//  DirectoryWalkTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct DirectoryWalkTests {
    @Test func libraryRootsIncludeHidden() {
        #expect(HiddenFilePolicy.forGrantedRoot(URL(fileURLWithPath: "/Users/test/Library")) == .includeHidden)
        #expect(HiddenFilePolicy.forGrantedRoot(URL(fileURLWithPath: "/Users/test/Library/Caches")) == .includeHidden)
        #expect(HiddenFilePolicy.forGrantedRoot(URL(fileURLWithPath: "/Library")) == .includeHidden)
    }

    @Test func documentsAndDownloadsSkipHidden() {
        #expect(HiddenFilePolicy.forGrantedRoot(URL(fileURLWithPath: "/Users/test/Documents")) == .skipHidden)
        #expect(HiddenFilePolicy.forGrantedRoot(URL(fileURLWithPath: "/Users/test/Downloads")) == .skipHidden)
    }

    @Test func fileSizeMatchesAllocatedResourceValues() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-size-\(UUID().uuidString).bin")
        let payload = Data(repeating: 4, count: 32_768)
        try payload.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let values = try url.resourceValues(forKeys: [
            .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
        ])
        let expected = DirectoryWalk.allocatedSize(from: values)
        #expect(FileSizeCalculator.size(of: url) == expected)
        #expect(expected >= Int64(payload.count))
    }

    @Test func directorySizeSumsChildren() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 4_096).write(to: root.appendingPathComponent("a.bin"))
        try Data(repeating: 2, count: 8_192).write(to: root.appendingPathComponent("b.bin"))

        let total = FileSizeCalculator.size(of: root)
        #expect(total >= 4_096 + 8_192)
    }

    @Test func walkMarksIncompleteAtFileCap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-walk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for i in 0..<6 {
            try Data([UInt8(i)]).write(to: root.appendingPathComponent("f-\(i).bin"))
        }

        var options = DirectoryWalk.Options.forRoot(root, maxFiles: 3)
        options.hidden = .skipHidden
        let outcome = DirectoryWalk.walk(root: root, options: options, initial: 0) { count, visit in
            if visit.isRegularFile { count += 1 }
        }
        #expect(outcome.incomplete)
    }

    @Test func largeFilesReportsIncompleteInsteadOfSilentCap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mc-large-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for i in 0..<5 {
            try Data(repeating: UInt8(i + 1), count: 2_048).write(to: root.appendingPathComponent("big-\(i).bin"))
        }

        let result = LargeFilesScanner(minimumBytes: 1, itemLimit: 2, fileCap: 80_000)
            .scan(roots: [root])
        #expect(result.items.count == 2)
        #expect(result.incomplete)
        #expect(result.warning?.contains("2") == true)
        #expect(result.items[0].byteSize >= result.items[1].byteSize)
    }
}
