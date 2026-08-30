//
//  ScanSessionStore.swift
//  mac_cleaner
//
//  Scan progress and Smart Scan summaries. Per-module arrays live on ScanResultsHub.
//

import Foundation
import Combine

final class ScanSessionStore: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var progressPercent: Int = 0
    @Published var progressLabel = "Ready to scan"
    @Published var lastScanDate: Date?
    @Published var resultsMayBeStale = false

    @Published var categorySummaries: [SmartScanCategoryResult] = []
    @Published var summary: SmartScanSummary = .empty
    @Published var scanStages: [SmartScanStage] = SmartScanStageID.allCases.map {
        SmartScanStage(id: $0, status: .pending, detail: nil)
    }

    @Published var applicationCount = 0
    @Published var applicationsBytes: Int64 = 0
    @Published var coverageTitles: [String] = []
    @Published var scannerWarnings: [String] = []
    /// Fires after a successful scan so the UI can play a completion moment.
    @Published var completionToken: UUID?

    var hasResults: Bool {
        lastScanDate != nil
    }

    var totalFoundBytes: Int64 {
        summary.totalDiscoveredSize
    }

    func updateProgress(_ value: Double, label: String) {
        let clamped = min(max(value, 0), 1)
        progress = clamped
        progressPercent = Int((clamped * 100).rounded())
        progressLabel = label
    }

    func resetStages() {
        scanStages = SmartScanStageID.allCases.map {
            SmartScanStage(id: $0, status: .pending, detail: nil)
        }
    }

    func setStage(_ id: SmartScanStageID, status: SmartScanStageStatus, detail: String? = nil) {
        guard let index = scanStages.firstIndex(where: { $0.id == id }) else { return }
        scanStages[index].status = status
        scanStages[index].detail = detail
    }

    func applyMetadata(
        appCount: Int,
        appBytes: Int64,
        coverageTitles: [String],
        warnings: [String]
    ) {
        applicationCount = appCount
        applicationsBytes = appBytes
        self.coverageTitles = coverageTitles
        scannerWarnings = warnings
        lastScanDate = Date()
        resultsMayBeStale = false
        isScanning = false
        updateProgress(1, label: "Scan complete")
    }

    func markStale() {
        guard hasResults else { return }
        resultsMayBeStale = true
    }

    func markCancelled() {
        isScanning = false
        for i in scanStages.indices {
            if scanStages[i].status == .running || scanStages[i].status == .pending {
                scanStages[i].status = .skipped
                if scanStages[i].detail == nil {
                    scanStages[i].detail = "Cancelled"
                }
            }
        }
        updateProgress(progress, label: hasResults ? "Scan cancelled — previous results kept" : "Scan cancelled")
    }

    func rebuildSummaries(from results: ScanResultsHub) {
        let built = SmartScanAggregator.build(
            space: results.space.categories,
            large: results.largeFiles.items,
            dupes: results.duplicates.groups,
            orphans: results.orphans.items,
            appCount: applicationCount,
            appBytes: applicationsBytes,
            coverageTitles: coverageTitles,
            warnings: scannerWarnings,
            lastScanDate: lastScanDate,
            resultsMayBeStale: resultsMayBeStale
        )
        categorySummaries = built.summaries
        summary = built.summary
    }

    func announceCompletion() {
        completionToken = UUID()
    }
}
