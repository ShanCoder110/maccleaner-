//
//  ScanCoordinator.swift
//  mac_cleaner
//
//  Sequential Smart Scan with cooperative cancel. Does not capture BookmarkStore.
//

import Foundation

enum ScanCoordinator {
    static func run(
        scope: ScanScope,
        session: ScanSessionStore,
        results: ScanResultsHub,
        leftoverSensitivity: LeftoverSensitivity = .enhanced
    ) async {
        session.isScanning = true
        session.resultsMayBeStale = false
        session.scannerWarnings = []
        session.coverageTitles = scope.coverageTitles
        session.resetStages()
        session.updateProgress(0.02, label: "Starting scan…")

        var warnings: [String] = []
        var space: [SpaceCategory] = []
        var large: [StorageItem] = []
        var largeResult = LargeFilesScanResult(
            items: [],
            incomplete: false,
            itemLimit: 300,
            fileCap: DirectoryWalk.defaultFileCap
        )
        var dupes: [DuplicateGroup] = []
        var orphans: [LeftoverItem] = []
        var apps: [InstalledApp] = []

        do {
            try Task.checkCancellation()
            setStage(session, .cachesLogs, .running, progress: 0.08, label: "Scanning catalogs, caches & logs…")
            space = await ScanTask.detached {
                SpaceCleanerScanner(scope: scope).scan()
            }
            try Task.checkCancellation()
            complete(session, .cachesLogs, ByteFormat.string(from: space.reduce(0) { $0 + $1.totalBytes }))

            try Task.checkCancellation()
            setStage(session, .largeFiles, .running, progress: 0.24, label: "Finding large files…")
            if scope.isEmpty {
                skip(session, .largeFiles, "No folders")
                warnings.append("Large files limited — authorize folders to scan")
            } else {
                let outcome = await ScanTask.detached {
                    LargeFilesScanner(minimumBytes: 50 * 1024 * 1024).scan(roots: scope.roots)
                }
                try Task.checkCancellation()
                largeResult = outcome
                large = outcome.items
                if let warning = outcome.warning {
                    warnings.append(warning)
                }
                complete(session, .largeFiles, ByteFormat.string(from: large.reduce(0) { $0 + $1.byteSize }))
            }

            try Task.checkCancellation()
            setStage(session, .duplicates, .running, progress: 0.42, label: "Comparing duplicates…")
            if scope.isEmpty {
                skip(session, .duplicates, "No folders")
            } else {
                let outcome = await ScanTask.detached {
                    DuplicateFinder().findDuplicates(roots: scope.roots)
                }
                try Task.checkCancellation()
                dupes = outcome.groups
                warnings.append(contentsOf: outcome.warnings)
                results.duplicates.applyLimits(from: outcome)
                complete(session, .duplicates, ByteFormat.string(from: dupes.reduce(0) { $0 + $1.recoverableBytes }))
            }

            try Task.checkCancellation()
            setStage(session, .applications, .running, progress: 0.60, label: "Listing applications…")
            let inventory = await ScanTask.detached {
                AppInventoryService().loadInstalledApps()
            }
            apps = inventory.filter { !$0.isSystemApp }
            try Task.checkCancellation()
            complete(session, .applications, "\(apps.count) apps")

            try Task.checkCancellation()
            setStage(session, .orphans, .running, progress: 0.74, label: "Looking for leftovers…")
            if scope.isEmpty {
                skip(session, .orphans, "No folders")
            } else {
                let ownershipApps = inventory
                let sensitivity = leftoverSensitivity
                orphans = await ScanTask.detached {
                    OrphanScanner(sensitivity: sensitivity).scan(roots: scope.roots, installedApps: ownershipApps)
                }
                try Task.checkCancellation()
                complete(session, .orphans, ByteFormat.string(from: orphans.reduce(0) { $0 + $1.byteSize }))
            }

            try Task.checkCancellation()
            setStage(session, .aiData, .running, progress: 0.88, label: "Checking named catalogs…")
            let catalogBytes = space
                .filter { ["apple", "developer", "ai"].contains($0.id) }
                .reduce(Int64(0)) { $0 + $1.totalBytes }
            let catalogFound = space.contains { ["apple", "developer", "ai"].contains($0.id) && !$0.items.isEmpty }
            session.setStage(
                .aiData,
                status: catalogFound ? .completed : .skipped,
                detail: catalogFound ? ByteFormat.string(from: catalogBytes) : "None found"
            )

            var mergedSpace = space
            let catalogIDs: Set<String> = ["apple", "developer", "ai"]
            for i in mergedSpace.indices {
                mergedSpace[i].isExpanded = catalogIDs.contains(mergedSpace[i].id) || mergedSpace.count <= 3
            }

            let appBytes = apps.reduce(Int64(0)) { $0 + $1.byteSize }

            results.replace(space: mergedSpace, large: large, dupes: dupes, orphans: orphans)
            results.largeFiles.apply(largeResult)
            session.applyMetadata(
                appCount: apps.count,
                appBytes: appBytes,
                coverageTitles: scope.coverageTitles,
                warnings: warnings
            )
            session.rebuildSummaries(from: results)
        } catch is CancellationError {
            session.markCancelled()
        } catch {
            session.markCancelled()
            session.scannerWarnings.append(error.localizedDescription)
        }
    }

    @MainActor
    private static func setStage(
        _ session: ScanSessionStore,
        _ id: SmartScanStageID,
        _ status: SmartScanStageStatus,
        progress: Double,
        label: String
    ) {
        session.setStage(id, status: status)
        session.updateProgress(progress, label: label)
    }

    @MainActor
    private static func complete(_ session: ScanSessionStore, _ id: SmartScanStageID, _ detail: String) {
        session.setStage(id, status: .completed, detail: detail)
    }

    @MainActor
    private static func skip(_ session: ScanSessionStore, _ id: SmartScanStageID, _ detail: String) {
        session.setStage(id, status: .skipped, detail: detail)
    }
}
