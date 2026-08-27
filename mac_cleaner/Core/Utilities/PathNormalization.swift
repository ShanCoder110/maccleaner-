//
//  PathNormalization.swift
//  mac_cleaner
//

import Foundation

enum PathNormalization {
    static func normalizedForMatching(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    static func lettersOnly(_ value: String) -> String {
        String(normalizedForMatching(value).filter(\.isLetter))
    }

    static func strippingTrailingVersion(_ value: String) -> String {
        let pattern = #"[\s._-]*v?\d+(\.\d+)*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "")
    }

    static func kind(for url: URL) -> LeftoverKind {
        let path = url.path
        if url.pathExtension == "app" { return .appBundle }
        if path.contains("/Preferences") || url.pathExtension == "plist" { return .preferences }
        if path.contains("/Caches") { return .caches }
        if path.contains("/Application Support") { return .applicationSupport }
        if path.contains("/Containers") || path.contains("/Group Containers") { return .containers }
        if path.contains("/Logs") { return .logs }
        if path.contains("/LaunchAgents") || path.contains("/LaunchDaemons") { return .launchAgent }
        if path.contains("/Saved Application State") { return .savedState }
        return .other
    }

    static func isSensitivePath(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let path = url.path.lowercased()
        if name.contains("auth") || name.contains("credential") || name.contains("keychain") {
            return true
        }
        if name == "config.toml" || name.hasSuffix(".pem") || name.hasSuffix(".key") {
            return true
        }
        if path.contains("/.ssh") || path.contains("/.aws") {
            return true
        }
        return false
    }
}

extension String {
    func normalizedForMatching() -> String {
        PathNormalization.normalizedForMatching(self)
    }

    var lettersOnly: String {
        PathNormalization.lettersOnly(self)
    }

    func strippingTrailingVersion() -> String {
        PathNormalization.strippingTrailingVersion(self)
    }

    var bundleLastTwoComponents: String {
        let parts = split(separator: ".")
        guard parts.count >= 2 else { return normalizedForMatching() }
        return (parts.suffix(2).joined(separator: ".")).normalizedForMatching()
    }

    var bundleCompanyName: String? {
        let parts = split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let company = String(parts[1])
        return company.count >= 3 ? company.normalizedForMatching() : nil
    }
}
