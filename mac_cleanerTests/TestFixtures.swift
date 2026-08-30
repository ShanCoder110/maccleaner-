//
//  TestFixtures.swift
//  mac_cleanerTests
//

import Foundation
@testable import mac_cleaner

enum TestFixtures {
    static func app(
        name: String,
        bundleID: String,
        path: String? = nil,
        isSystem: Bool = false,
        size: Int64 = 1_000_000,
        lastOpened: Date? = nil
    ) -> InstalledApp {
        InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            path: URL(fileURLWithPath: path ?? "/Applications/\(name).app"),
            version: "1.0",
            isSystemApp: isSystem,
            byteSize: size,
            lastOpenedDate: lastOpened
        )
    }

    static func leftover(
        path: String,
        kind: LeftoverKind,
        size: Int64 = 10_000,
        selected: Bool? = nil,
        confidence: MatchConfidence = .likely,
        reason: MatchReason = .normalizedName,
        safety: SafetyClassification? = nil,
        shared: Bool = false,
        related: [String] = ["Test App"]
    ) -> LeftoverItem {
        LeftoverItem(
            url: URL(fileURLWithPath: path),
            kind: kind,
            byteSize: size,
            isSelected: selected,
            matchConfidence: confidence,
            matchReason: reason,
            safety: safety,
            isSharedOrPossiblyShared: shared,
            relatedInstalledAppNames: related
        )
    }
}
