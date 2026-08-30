//
//  OrphanScanner.swift
//  mac_cleaner
//
//  Candidates under granted Library-style folders that no installed app owns
//  at likely+ confidence (AppMatcher). Does not Spotlight the disk.
//

import Foundation

struct OrphanScanner: Sendable {
    var sensitivity: LeftoverSensitivity = .enhanced

    private static let libraryFolderNames = [
        "Caches", "Logs", "Application Support", "Preferences", "Containers"
    ]

    func scan(roots: [URL], installedApps: [InstalledApp]) -> [LeftoverItem] {
        guard !roots.isEmpty else { return [] }

        var items: [LeftoverItem] = []
        for root in roots {
            if Task.isCancelled { break }
            items.append(contentsOf: classify(candidates: candidates(in: root), installedApps: installedApps))
        }
        return items.sorted { $0.byteSize > $1.byteSize }
    }

    func classify(
        candidates: [URL],
        installedApps: [InstalledApp],
        sizeOf: (URL) -> Int64 = { FileSizeCalculator.size(of: $0, maxDepth: 4) }
    ) -> [LeftoverItem] {
        var items: [LeftoverItem] = []

        for url in candidates {
            if Task.isCancelled { break }
            if AppMatcher.isOwnedByInstalledApp(url: url, apps: installedApps, sensitivity: sensitivity) {
                continue
            }

            let kind = PathNormalization.kind(for: url)
            let autoSelect = kind == .caches || kind == .logs
            let size = sizeOf(url)
            guard size > 32 * 1024 else { continue }

            items.append(
                LeftoverItem(
                    url: url,
                    kind: kind,
                    byteSize: size,
                    isSelected: autoSelect,
                    isSensitive: !autoSelect || PathNormalization.isSensitivePath(url),
                    isRootOwned: FileOwnership.isOwnedByRoot(url)
                )
            )
        }

        return items
    }

    private func candidates(in root: URL) -> [URL] {
        let hidden = HiddenFilePolicy.forGrantedRoot(root)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: hidden.enumeratorOptions
        ) else { return [] }

        if Self.libraryFolderNames.contains(root.lastPathComponent) {
            return contents
        }

        return contents.flatMap { child -> [URL] in
            guard Self.libraryFolderNames.contains(child.lastPathComponent) else { return [] }
            return (try? FileManager.default.contentsOfDirectory(
                at: child,
                includingPropertiesForKeys: nil,
                options: HiddenFilePolicy.forGrantedRoot(child).enumeratorOptions
            )) ?? []
        }
    }
}
