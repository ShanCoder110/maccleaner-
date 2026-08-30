//
//  AppMatcher.swift
//  mac_cleaner
//
//  Leftover name matching. Confidence is separate from deletion safety.
//

import Foundation

nonisolated struct MatchHit: Sendable {
    let confidence: MatchConfidence
    let reason: MatchReason
}

nonisolated struct AppMatcher: Sendable {
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

    /// Returns the strongest match hit, or nil.
    func matches(name: String, url: URL) -> MatchHit? {
        let normalized = name.normalizedForMatching()
        guard !normalized.isEmpty else { return nil }

        let pathNorm = url.path.normalizedForMatching()

        if normalized == normalizedBundleID
            || normalized.contains(normalizedBundleID)
            || pathNorm.contains(normalizedBundleID) {
            return MatchHit(confidence: .confirmed, reason: .bundleIdentifier)
        }

        let minLen = 5

        if normalizedName.count >= minLen {
            if normalized == normalizedName {
                return MatchHit(confidence: .likely, reason: .exactAppName)
            }
            if sensitivity != .strict, normalized.contains(normalizedName) {
                return MatchHit(confidence: .likely, reason: .normalizedName)
            }
        }

        if pathComponent.count >= minLen {
            if normalized == pathComponent {
                return MatchHit(confidence: .likely, reason: .exactPathComponent)
            }
            if sensitivity != .strict, normalized.contains(pathComponent) {
                return MatchHit(confidence: .likely, reason: .exactPathComponent)
            }
        }

        if sensitivity == .strict { return nil }

        if lettersName.count >= minLen, normalized.contains(lettersName) {
            return MatchHit(confidence: .likely, reason: .normalizedName)
        }

        guard sensitivity == .deep else { return nil }

        if bundleLastTwo.count >= minLen, normalized.contains(bundleLastTwo) {
            return MatchHit(confidence: .possible, reason: .bundleLastComponents)
        }

        if let strippedName, strippedName.count >= minLen, normalized.contains(strippedName) {
            return MatchHit(confidence: .possible, reason: .versionSuffixStripped)
        }

        if let company, company.count >= minLen, normalized.contains(company) {
            return MatchHit(confidence: .possible, reason: .vendorName)
        }

        return nil
    }

    /// True when any installed app owns this path at likely+ confidence.
    static func isOwnedByInstalledApp(
        url: URL,
        apps: [InstalledApp],
        sensitivity: LeftoverSensitivity
    ) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent
        for app in apps {
            guard let hit = AppMatcher(app: app, sensitivity: sensitivity).matches(name: name, url: url) else {
                continue
            }
            if hit.confidence.isLikelyOrBetter {
                return true
            }
        }
        return false
    }
}
