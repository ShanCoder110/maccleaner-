//
//  LeftoverFinderTests.swift
//  mac_cleanerTests
//

import Foundation
import Testing
@testable import mac_cleaner

struct LeftoverFinderTests {
    @Test func sharedVendorFolderIsUnselectedAndNotConfirmed() throws {
        let root = try makeScratchRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        let shared = caches.appendingPathComponent("Pixelmator")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: shared.appendingPathComponent("store.db"))

        let pixelmator = TestFixtures.app(
            name: "Pixelmator",
            bundleID: "com.pixelmator.pixelmator",
            path: "/Applications/Pixelmator.app"
        )
        let pro = TestFixtures.app(
            name: "Pixelmator Pro",
            bundleID: "com.pixelmator.pixelmatorpro",
            path: "/Applications/Pixelmator Pro.app"
        )

        let result = LeftoverFinderService.findLeftovers(
            for: pixelmator,
            sensitivity: .enhanced,
            allInstalledApps: [pixelmator, pro],
            roots: [caches],
            searchedFolderTitles: ["Caches"]
        )

        let leftover = result.items.first { $0.url.lastPathComponent == "Pixelmator" }
        #expect(leftover != nil)
        #expect(leftover?.isSharedOrPossiblyShared == true)
        #expect(leftover?.isSelected == false)
        #expect(leftover?.matchConfidence != .confirmed)
        #expect(leftover?.relatedInstalledAppNames.contains("Pixelmator Pro") == true)
    }

    @Test func exclusiveBundleIDLeftoverStaysConfirmed() throws {
        let root = try makeScratchRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        let folder = caches.appendingPathComponent("com.example.onlyapp")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("cache"))

        let only = TestFixtures.app(name: "OnlyApp", bundleID: "com.example.onlyapp")
        let other = TestFixtures.app(name: "OtherApp", bundleID: "com.other.otherapp")

        let result = LeftoverFinderService.findLeftovers(
            for: only,
            sensitivity: .enhanced,
            allInstalledApps: [only, other],
            roots: [caches],
            searchedFolderTitles: ["Caches"]
        )

        let leftover = result.items.first { $0.url.lastPathComponent == "com.example.onlyapp" }
        #expect(leftover?.matchConfidence == .confirmed)
        #expect(leftover?.isSharedOrPossiblyShared == false)
        #expect(leftover?.isSelected == true)
    }

    private func makeScratchRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("maccleaner-leftover-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
