//
//  AppleJunkCatalog.swift
//  mac_cleaner
//

import Foundation

enum AppleJunkCatalog {
    static let entries: [SpaceCatalogEntry] = [
        SpaceCatalogEntry(
            title: "iPhone & iPad Backups",
            relativePath: "Library/Application Support/MobileSync/Backup",
            category: "Apple",
            isSensitive: true,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "Mail Downloads",
            relativePath: "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
            category: "Mail",
            isSensitive: true,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "Safari Caches",
            relativePath: "Library/Caches/com.apple.Safari",
            category: "Safari",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Chrome Caches",
            relativePath: "Library/Caches/Google/Chrome",
            category: "Chrome",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Firefox Caches",
            relativePath: "Library/Caches/Firefox",
            category: "Firefox",
            isSensitive: false,
            defaultSelected: true
        )
    ]
}
