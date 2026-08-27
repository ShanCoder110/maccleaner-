//
//  AppInventoryService.swift
//  mac_cleaner
//

import Foundation
import AppKit

struct AppInventoryService {
    func loadInstalledApps() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: BookmarkStore.realUserHomePath()).appendingPathComponent("Applications")
        ]

        var apps: [InstalledApp] = []
        let fm = FileManager.default

        for root in roots {
            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                guard let app = makeApp(from: url) else { continue }
                apps.append(app)
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func makeApp(from url: URL) -> InstalledApp? {
        let bundle = Bundle(url: url)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let isSystem = bundleID.hasPrefix("com.apple.") || url.path.hasPrefix("/System")

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            path: url,
            version: version,
            isSystemApp: isSystem,
            byteSize: FileSizeCalculator.size(of: url, maxDepth: 4)
        )
    }

    func icon(for app: InstalledApp) -> NSImage {
        NSWorkspace.shared.icon(forFile: app.path.path)
    }
}
