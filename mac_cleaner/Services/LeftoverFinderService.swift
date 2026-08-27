//
//  LeftoverFinderService.swift
//  mac_cleaner
//
//  Scoped leftover matching — only searches authorized bookmark roots.
//

import Foundation

struct LeftoverFinderService {
    let bookmarks: BookmarkStore

    func findLeftovers(
        for app: InstalledApp,
        sensitivity: LeftoverSensitivity = .enhanced
    ) -> [LeftoverItem] {
        var results: [URL: LeftoverItem] = [:]

        // Always include the app bundle itself when uninstalling.
        results[app.path.standardizedFileURL] = LeftoverItem(
            url: app.path,
            kind: .appBundle,
            byteSize: app.byteSize > 0 ? app.byteSize : FileSizeCalculator.size(of: app.path, maxDepth: 4),
            isSelected: true
        )

        let roots = bookmarks.accessibleRootURLs
        guard !roots.isEmpty else {
            return Array(results.values).sorted { $0.byteSize > $1.byteSize }
        }

        let matcher = AppMatcher(app: app, sensitivity: sensitivity)

        for root in roots {
            scan(root: root, depth: 0, maxDepth: maxDepth(for: root), matcher: matcher, into: &results)
        }

        return Array(results.values).sorted { $0.byteSize > $1.byteSize }
    }

    private func maxDepth(for root: URL) -> Int {
        let path = root.path
        if path.hasSuffix("Library") || path.hasSuffix("Application Support") {
            return 2
        }
        return 1
    }

    private func scan(
        root: URL,
        depth: Int,
        maxDepth: Int,
        matcher: AppMatcher,
        into results: inout [URL: LeftoverItem]
    ) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for itemURL in contents {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }

            let name = itemURL.deletingPathExtension().lastPathComponent
            if matcher.matches(name: name, url: itemURL) {
                let standardized = itemURL.standardizedFileURL
                if results[standardized] == nil {
                    let kind = PathNormalization.kind(for: standardized)
                    let sensitive = PathNormalization.isSensitivePath(standardized)
                    results[standardized] = LeftoverItem(
                        url: standardized,
                        kind: kind,
                        byteSize: FileSizeCalculator.size(of: standardized, maxDepth: 5),
                        isSelected: !sensitive,
                        isSensitive: sensitive
                    )
                }
            }

            if values?.isDirectory == true, depth < maxDepth {
                // Skip deep Apple system containers noise
                let last = itemURL.lastPathComponent
                if last == "Caches" || last == "Logs" || last == "Preferences"
                    || last == "Application Support" || last == "Containers"
                    || last == "Group Containers" || last == "Saved Application State"
                    || last == "LaunchAgents" || depth > 0 {
                    scan(root: itemURL, depth: depth + 1, maxDepth: maxDepth, matcher: matcher, into: &results)
                }
            }
        }
    }
}

private struct AppMatcher {
    let sensitivity: LeftoverSensitivity
    let normalizedBundleID: String
    let normalizedName: String
    let pathComponent: String
    let lettersName: String
    let bundleLastTwo: String
    let company: String?
    let strippedName: String?

    init(app: InstalledApp, sensitivity: LeftoverSensitivity) {
        self.sensitivity = sensitivity
        self.normalizedBundleID = app.bundleIdentifier.normalizedForMatching()
        self.normalizedName = app.name.normalizedForMatching()
        self.pathComponent = app.path.deletingPathExtension().lastPathComponent.normalizedForMatching()
        self.lettersName = app.name.lettersOnly
        self.bundleLastTwo = app.bundleIdentifier.bundleLastTwoComponents
        self.company = app.bundleIdentifier.bundleCompanyName
        let stripped = app.name.strippingTrailingVersion().normalizedForMatching()
        self.strippedName = stripped != normalizedName && !stripped.isEmpty ? stripped : nil
    }

    func matches(name: String, url: URL) -> Bool {
        let normalized = name.normalizedForMatching()
        guard !normalized.isEmpty else { return false }

        // Bundle ID exact / contains
        if normalized == normalizedBundleID || normalized.contains(normalizedBundleID) {
            return true
        }

        let minLen = 5
        let strict = sensitivity == .strict

        if normalizedName.count >= minLen {
            if strict ? normalized == normalizedName : normalized.contains(normalizedName) {
                return true
            }
        }

        if pathComponent.count >= minLen {
            if strict ? normalized == pathComponent : normalized.contains(pathComponent) {
                return true
            }
        }

        if sensitivity == .strict { return false }

        if lettersName.count >= minLen, normalized.contains(lettersName) {
            return true
        }

        if bundleLastTwo.count >= minLen, normalized.contains(bundleLastTwo) {
            return true
        }

        if let strippedName, strippedName.count >= minLen, normalized.contains(strippedName) {
            return true
        }

        if sensitivity == .deep, let company, company.count >= minLen, normalized.contains(company) {
            return true
        }

        // Preferential match on full path for containers
        let pathNorm = url.path.normalizedForMatching()
        if pathNorm.contains(normalizedBundleID) { return true }

        return false
    }
}
