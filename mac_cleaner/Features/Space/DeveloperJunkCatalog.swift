//
//  DeveloperJunkCatalog.swift
//  mac_cleaner
//

import Foundation

enum DeveloperJunkCatalog {
    static let entries: [SpaceCatalogEntry] = [
        SpaceCatalogEntry(
            title: "Xcode DerivedData",
            relativePath: "Library/Developer/Xcode/DerivedData",
            category: "Xcode",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Xcode Caches",
            relativePath: "Library/Caches/com.apple.dt.Xcode",
            category: "Xcode",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Xcode Documentation Cache",
            relativePath: "Library/Developer/Xcode/DocumentationCache",
            category: "Xcode",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "iOS Device Support",
            relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
            category: "Xcode",
            isSensitive: false,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "Xcode Archives",
            relativePath: "Library/Developer/Xcode/Archives",
            category: "Xcode",
            isSensitive: true,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "Simulator Data",
            relativePath: "Library/Developer/CoreSimulator",
            category: "Xcode",
            isSensitive: true,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "Homebrew Cache",
            relativePath: "Library/Caches/Homebrew",
            category: "Homebrew",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "CocoaPods Cache",
            relativePath: "Library/Caches/CocoaPods",
            category: "CocoaPods",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Swift Package Cache",
            relativePath: "Library/Caches/org.swift.swiftpm",
            category: "SwiftPM",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "npm Cache",
            relativePath: ".npm",
            category: "npm",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Yarn Cache",
            relativePath: "Library/Caches/Yarn",
            category: "Yarn",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "pnpm Store",
            relativePath: "Library/pnpm",
            category: "pnpm",
            isSensitive: false,
            defaultSelected: true
        ),
        SpaceCatalogEntry(
            title: "Docker VM Disk",
            relativePath: "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
            category: "Docker",
            isSensitive: true,
            defaultSelected: false
        ),
        SpaceCatalogEntry(
            title: "OrbStack Data",
            relativePath: "Library/Application Support/OrbStack",
            category: "OrbStack",
            isSensitive: true,
            defaultSelected: false
        )
    ]
}
