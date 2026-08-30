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
        await MainActor.run {
            session.isScanning = true
            session.resultsMayBeStale = false
            session.scannerWarnings = []
            session.coverageTitles = scope.coverageTitles
            session.resetStages()
            session.updateProgress(0.02, label: "Starting scan…")
        }

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
            await setStage(session, .cachesLogs, .running, progress: 0.08, label: "Scanning catalogs, caches & logs…")
            space = await ScanTask.detached {
                SpaceCleanerScanner(scope: scope).scan()
            }
            try Task.checkCancellation()
            await complete(session, .cachesLogs, ByteFormat.string(from: space.reduce(0) { $0 + $1.totalBytes }))

            try Task.checkCancellation()
            await setStage(session, .largeFiles, .running, progress: 0.24, label: "Finding large files…")
            if scope.isEmpty {
                await skip(session, .largeFiles, "No folders")
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
                await complete(session, .largeFiles, ByteFormat.string(from: large.reduce(0) { $0 + $1.byteSize }))
            }

            try Task.checkCancellation()
            await setStage(session, .duplicates, .running, progress: 0.42, label: "Comparing duplicates…")
            if scope.isEmpty {
                await skip(session, .duplicates, "No folders")
            } else {
                let outcome = await ScanTask.detached {
                    DuplicateFinder().findDuplicates(roots: scope.roots)
                }
                try Task.checkCancellation()
                dupes = outcome.groups
                warnings.append(contentsOf: outcome.warnings)
                await MainActor.run {
                    results.duplicates.applyLimits(from: outcome)
                }
                await complete(session, .duplicates, ByteFormat.string(from: dupes.reduce(0) { $0 + $1.recoverableBytes }))
            }

            try Task.checkCancellation()
            await setStage(session, .applications, .running, progress: 0.60, label: "Listing applications…")
            let inventory = await ScanTask.detached {
                AppInventoryService().loadInstalledApps()
            }
            apps = inventory.filter { !$0.isSystemApp }
            try Task.checkCancellation()
            await complete(session, .applications, "\(apps.count) apps")

            try Task.checkCancellation()
            await setStage(session, .orphans, .running, progress: 0.74, label: "Looking for leftovers…")
            if scope.isEmpty {
                await skip(session, .orphans, "No folders")
            } else {
                let ownershipApps = inventory
                let sensitivity = leftoverSensitivity
                orphans = await ScanTask.detached {
                    OrphanScanner(sensitivity: sensitivity).scan(roots: scope.roots, installedApps: ownershipApps)
                }
                try Task.checkCancellation()
                await complete(session, .orphans, ByteFormat.string(from: orphans.reduce(0) { $0 + $1.byteSize }))
            }

            try Task.checkCancellation()
            await setStage(session, .aiData, .running, progress: 0.88, label: "Checking named catalogs…")
            let catalogBytes = space
                .filter { ["apple", "developer", "ai"].contains($0.id) }
                .reduce(Int64(0)) { $0 + $1.totalBytes }
            let catalogFound = space.contains { ["apple", "developer", "ai"].contains($0.id) && !$0.items.isEmpty }
            await MainActor.run {
                session.setStage(
                    .aiData,
                    status: catalogFound ? .completed : .skipped,
                    detail: catalogFound ? ByteFormat.string(from: catalogBytes) : "None found"
                )
            }

            var mergedSpace = space
            let catalogIDs: Set<String> = ["apple", "developer", "ai"]
            for i in mergedSpace.indices {
                mergedSpace[i].isExpanded = catalogIDs.contains(mergedSpace[i].id) || mergedSpace.count <= 3
            }

            let appBytes = apps.reduce(Int64(0)) { $0 + $1.byteSize }

            await MainActor.run {
                results.replace(space: mergedSpace, large: large, dupes: dupes, orphans: orphans)
                results.largeFiles.apply(largeResult)
                session.applyMetadata(
                    appCount: apps.count,
                    appBytes: appBytes,
                    coverageTitles: scope.coverageTitles,
                    warnings: warnings
                )
                session.rebuildSummaries(from: results)
            }
        } catch is CancellationError {
            await MainActor.run {
                session.markCancelled()
            }
        } catch {
            await MainActor.run {
                session.markCancelled()
                session.scannerWarnings.append(error.localizedDescription)
            }
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
