//
//  ApplicationsViewModel.swift
//  mac_cleaner
//

import Foundation
import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class ApplicationsViewModel {
    var apps: [InstalledApp] = []
    var leftoversByAppID: [String: [LeftoverItem]] = [:]
    var summariesByAppID: [String: AppStorageSummary] = [:]
    var searchedFoldersByAppID: [String: [String]] = [:]
    var loadingLeftovers: Set<String> = []

    var searchText = ""
    var filter: AppListFilter = .all
    var sort: AppListSort = .name
    var unusedThreshold: UnusedThreshold = .sixMonths

    var isLoading = false
    var isUninstalling = false
    var showConfirmSheet = false
    var showResultSheet = false
    var whyItem: LeftoverItem?
    var resultSummary: UninstallResultSummary?
    var progress: Double = 0
    var statusMessage = ""

    @ObservationIgnored private var scopeToken = ""
    @ObservationIgnored private let inventory = AppInventoryService()
    @ObservationIgnored private let scanCache = LeftoverScanCache.shared
    @ObservationIgnored private var appState: AppState?

    func attach(_ appState: AppState) {
        let isFirst = self.appState == nil
        self.appState = appState
        if isFirst {
            reload()
            refreshScopeToken()
        }
    }

    var filteredApps: [InstalledApp] {
        let matching = apps.filter { app in
            AppListFiltering.matches(
                app: app,
                filter: filter,
                searchText: searchText,
                unusedThreshold: unusedThreshold,
                totalDiscoveredSize: totalSize(for: app)
            )
        }
        return AppListFiltering.sorted(matching, by: sort, totalSize: totalSize(for:))
    }

    var selectedApps: [InstalledApp] {
        apps.filter(\.isSelected)
    }

    var selectedLeftoverItems: [LeftoverItem] {
        selectedApps.flatMap { leftoversByAppID[$0.id] ?? [] }.filter(\.isSelected)
    }

    var filterEmptyTitle: String {
        switch filter {
        case .all: return "No applications found"
        case .selected: return "No apps selected"
        case .large: return "No large apps"
        case .unused: return "No unused apps"
        }
    }

    var filterEmptyMessage: String {
        switch filter {
        case .all:
            return "Drop an app here or refresh the list from /Applications."
        case .selected:
            return "Select one or more apps with the checkbox to focus on them here."
        case .large:
            return "No apps at or above 500 MB (app size or discovered total) matched this filter."
        case .unused:
            return "No apps appear unused for \(unusedThreshold.title). Last-opened dates come from macOS when available and may be approximate."
        }
    }

    var filterHint: String {
        switch filter {
        case .all:
            return appState?.sensitivity.detail ?? LeftoverSensitivity.enhanced.detail
        case .selected:
            return "Showing \(filteredApps.count) selected app\(filteredApps.count == 1 ? "" : "s")."
        case .large:
            return "Showing apps ≥ 500 MB by app size or discovered total storage."
        case .unused:
            return "Showing apps unused for \(unusedThreshold.title) (approximate last-opened from macOS)."
        }
    }

    func icon(for app: InstalledApp) -> NSImage {
        inventory.icon(for: app)
    }

    func appSelectionBinding(for app: InstalledApp) -> Binding<Bool> {
        Binding(
            get: { self.apps.first(where: { $0.id == app.id })?.isSelected ?? false },
            set: { newValue in
                if let index = self.apps.firstIndex(where: { $0.id == app.id }) {
                    self.apps[index].isSelected = newValue
                }
            }
        )
    }

    func leftoverSelectionBinding(appID: String, itemID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                self.leftoversByAppID[appID]?.first(where: { $0.id == itemID })?.isSelected ?? false
            },
            set: { newValue in
                guard var items = self.leftoversByAppID[appID],
                      let index = items.firstIndex(where: { $0.id == itemID }) else { return }
                items[index].isSelected = newValue
                self.leftoversByAppID[appID] = items
            }
        )
    }

    func toggleSelection(_ id: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].isSelected.toggle()
    }

    func toggleExpanded(_ app: InstalledApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isExpanded.toggle()
        if apps[index].isExpanded {
            Task { await loadLeftovers(for: apps[index], force: false) }
        }
    }

    func totalSize(for app: InstalledApp) -> Int64 {
        if let summary = summariesByAppID[app.id], summary.lastScanDate != nil {
            return summary.totalDiscoveredSize
        }
        return app.byteSize
    }

    func reload() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [inventory] in
            let loaded = inventory.loadInstalledApps()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apps = loaded
                self.hydrateSummariesFromCache(for: loaded)
                self.isLoading = false
            }
        }
    }

    func loadLeftovers(for app: InstalledApp, force: Bool) async {
        guard let appState else { return }

        if !force, leftoversByAppID[app.id] != nil {
            return
        }

        if !force,
           let cached = scanCache.cachedScan(for: app, bookmarks: appState.bookmarks, sensitivity: appState.sensitivity) {
            apply(resultItems: scanCache.items(from: cached), titles: cached.searchedFolderTitles, scannedAt: cached.scannedAt, cached: true, for: app)
            return
        }

        loadingLeftovers.insert(app.id)
        let sensitivity = appState.sensitivity
        let roots = appState.bookmarks.accessibleRootURLs
        let folderTitles = appState.bookmarks.folders.map(\.kind.title).sorted()
        let bookmarks = appState.bookmarks
        let allApps = apps
        let result = await Task.detached(priority: .userInitiated) {
            LeftoverFinderService.findLeftovers(
                for: app,
                sensitivity: sensitivity,
                allInstalledApps: allApps,
                roots: roots,
                searchedFolderTitles: folderTitles
            )
        }.value

        apply(resultItems: result.items, titles: result.searchedFolderTitles, scannedAt: result.scannedAt, cached: false, for: app)
        scanCache.store(result, for: app, bookmarks: bookmarks, sensitivity: sensitivity)
        loadingLeftovers.remove(app.id)
        appState.activityLog.log(.scan, "Found \(result.items.count) related items for \(app.name)")
    }

    func prepareConfirm() async {
        for app in selectedApps where leftoversByAppID[app.id] == nil {
            await loadLeftovers(for: app, force: false)
        }
        showConfirmSheet = true
    }

    func uninstallSelected() async {
        guard let appState else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        let appsSnapshot = selectedApps
        var urls: [URL] = []
        var relatedCount = 0

        for app in appsSnapshot {
            if leftoversByAppID[app.id] == nil {
                await loadLeftovers(for: app, force: false)
            }
            let leftovers = leftoversByAppID[app.id] ?? [
                LeftoverItem(
                    url: app.path,
                    kind: .appBundle,
                    byteSize: app.byteSize,
                    matchConfidence: .confirmed,
                    matchReason: .appBundleItself,
                    safety: .reviewRecommended,
                    relatedInstalledAppNames: [app.name]
                )
            ]
            let selected = leftovers.filter(\.isSelected)
            relatedCount += selected.filter { $0.kind != .appBundle }.count
            urls.append(contentsOf: selected.map(\.url))
        }

        let result = await appState.cleaning.trash(urls: urls) { [weak self] value in
            self?.progress = value
        }

        let names = appsSnapshot.map(\.name)
        resultSummary = UninstallResultSummary(
            title: names.count == 1 ? "\(names[0]) moved to Trash" : "\(names.count) apps moved to Trash",
            freedLabel: ByteFormat.string(from: result.freedBytes),
            appCount: appsSnapshot.count,
            relatedCount: relatedCount,
            failedCount: result.errors.count,
            errorDetails: result.errors
        )
        showResultSheet = true
        statusMessage = "Moved \(result.trashedCount) items to Trash (\(ByteFormat.string(from: result.freedBytes)))."

        for app in appsSnapshot {
            leftoversByAppID.removeValue(forKey: app.id)
            summariesByAppID.removeValue(forKey: app.id)
            scanCache.invalidate(appIDKey: LeftoverScanCache.cacheKey(for: app))
        }
        reload()
    }

    func preview(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            appState?.cleaning.reveal(url)
            return
        }
        QuickLookPreview.shared.preview(url: url)
    }

    func reveal(_ url: URL) {
        appState?.cleaning.reveal(url)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] object, _ in
                guard let url = object, url.pathExtension == "app" else { return }
                DispatchQueue.main.async {
                    self?.ingestDroppedApp(at: url)
                }
            }
        }
        return true
    }

    func invalidateScansForScopeChange() {
        guard let appState else { return }
        let newToken = LeftoverScanCache.scopeSignature(
            bookmarks: appState.bookmarks,
            sensitivity: appState.sensitivity
        )
        guard newToken != scopeToken else { return }
        scopeToken = newToken
        leftoversByAppID.removeAll()
        summariesByAppID.removeAll()
        searchedFoldersByAppID.removeAll()
        hydrateSummariesFromCache(for: apps)
        for app in apps where app.isExpanded {
            Task { await loadLeftovers(for: app, force: true) }
        }
    }

    func openActivity() {
        appState?.selection = .activity
    }

    func openManagePermissions() {
        appState?.openManagePermissions()
    }

    var grantedFolderTitles: [String] {
        appState?.bookmarks.folders.map(\.kind.title) ?? []
    }

    var missingRecommendedKinds: [(GrantedFolder.Kind, String)] {
        let recommended: [(GrantedFolder.Kind, String)] = [
            (.applicationSupport, "Application Support"),
            (.caches, "Caches"),
            (.preferences, "Preferences"),
            (.logs, "Logs"),
            (.containers, "Containers")
        ]
        let granted = Set(appState?.bookmarks.folders.map(\.kind) ?? [])
        return recommended.filter { !granted.contains($0.0) }
    }

    private func ingestDroppedApp(at url: URL) {
        guard let installed = inventory.makeApp(from: url) else { return }
        if let index = apps.firstIndex(where: { $0.id == installed.id }) {
            apps[index].isSelected = true
            apps[index].isExpanded = true
            Task { await loadLeftovers(for: apps[index], force: false) }
        } else {
            var app = installed
            app.isSelected = true
            app.isExpanded = true
            apps.insert(app, at: 0)
            Task { await loadLeftovers(for: app, force: false) }
        }
        statusMessage = "Ready to review \(installed.name)."
    }

    private func apply(
        resultItems: [LeftoverItem],
        titles: [String],
        scannedAt: Date,
        cached: Bool,
        for app: InstalledApp
    ) {
        leftoversByAppID[app.id] = resultItems
        searchedFoldersByAppID[app.id] = titles
        summariesByAppID[app.id] = AppStorageSummary.from(
            items: resultItems,
            appBundleSize: app.byteSize,
            scannedAt: scannedAt,
            cached: cached
        )
    }

    private func hydrateSummariesFromCache(for loaded: [InstalledApp]) {
        guard let appState else { return }
        let sensitivity = appState.sensitivity
        for app in loaded where !app.isSystemApp {
            if let cached = scanCache.cachedScan(for: app, bookmarks: appState.bookmarks, sensitivity: sensitivity) {
                apply(
                    resultItems: scanCache.items(from: cached),
                    titles: cached.searchedFolderTitles,
                    scannedAt: cached.scannedAt,
                    cached: true,
                    for: app
                )
            }
        }
    }

    private func refreshScopeToken() {
        guard let appState else { return }
        scopeToken = LeftoverScanCache.scopeSignature(
            bookmarks: appState.bookmarks,
            sensitivity: appState.sensitivity
        )
    }
}
