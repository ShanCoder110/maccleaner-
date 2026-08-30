//
//  AppState.swift
//  mac_cleaner
//
//  Selection, paywall, onboarding, appearance, and permissions.
//  Feature stores are observed by views via environment objects.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    let bookmarks: BookmarkStore
    let activityLog: ActivityLogStore
    let scanSession: ScanSessionStore
    let scanResults: ScanResultsHub
    let subscription: SubscriptionStore

    @Published var sensitivity: LeftoverSensitivity {
        didSet { UserDefaults.standard.set(sensitivity.rawValue, forKey: "mas.sensitivity") }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "mas.appearanceMode") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "mas.onboardingComplete") }
    }

    @Published var showManagePermissions: Bool = false
    @Published var showPaywall: Bool = false
    @Published var pendingProDestination: AppDestination?

    @Published var selection: AppDestination = .smartScan
    @Published private(set) var diskFreeLabel: String = "—"
    @Published private(set) var diskUsage: Double = 0

    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?

    init(
        bookmarks: BookmarkStore = BookmarkStore(),
        activityLog: ActivityLogStore = ActivityLogStore(),
        scanSession: ScanSessionStore = ScanSessionStore(),
        scanResults: ScanResultsHub? = nil,
        subscription: SubscriptionStore = SubscriptionStore()
    ) {
        self.bookmarks = bookmarks
        self.activityLog = activityLog
        self.scanSession = scanSession
        self.scanResults = scanResults ?? ScanResultsHub()
        self.subscription = subscription

        if let raw = UserDefaults.standard.string(forKey: "mas.sensitivity"),
           let value = LeftoverSensitivity(rawValue: raw) {
            sensitivity = value
        } else {
            sensitivity = .enhanced
        }

        if let raw = UserDefaults.standard.string(forKey: "mas.appearanceMode"),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        } else {
            appearanceMode = .system
        }

        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "mas.onboardingComplete")

        let flowVersion = 3
        if UserDefaults.standard.integer(forKey: "mas.permissionFlowVersion") < flowVersion {
            UserDefaults.standard.set(flowVersion, forKey: "mas.permissionFlowVersion")
            hasCompletedOnboarding = false
        }

        bookmarks.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.markScanStale()
            }
            .store(in: &cancellables)
    }

    var cleaning: CleaningService {
        CleaningService(bookmarks: bookmarks, log: activityLog)
    }

    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    func navigate(to destination: AppDestination) {
        if FeatureGate.requiresPro(for: destination), !subscription.isPro {
            pendingProDestination = destination
            presentPaywall()
            return
        }
        selection = destination
    }

    func presentPaywall() {
        showPaywall = true
    }

    func handlePaywallPurchaseSuccess() {
        if let pending = pendingProDestination {
            selection = pending
            pendingProDestination = nil
        }
    }

    func requireProForCleanJunk() -> Bool {
        guard FeatureGate.cleanJunkRequiresPro else { return true }
        if subscription.isPro { return true }
        presentPaywall()
        return false
    }

    func runSmartScan() async {
        guard !scanSession.isScanning else { return }
        activityLog.log(.scan, "Smart Scan started")
        let scope = ScanScope.snapshot(from: bookmarks)
        let leftoverSensitivity = sensitivity
        let session = scanSession
        let results = scanResults
        let task = Task {
            await ScanCoordinator.run(
                scope: scope,
                session: session,
                results: results,
                leftoverSensitivity: leftoverSensitivity
            )
        }
        scanTask = task
        await task.value
        let cancelled = task.isCancelled
        scanTask = nil
        activityLog.log(.scan, cancelled ? "Smart Scan cancelled" : "Smart Scan finished")
        refreshDiskStats()
    }

    func cancelSmartScan() {
        scanTask?.cancel()
    }

    func rebuildScanSummaries() {
        scanSession.rebuildSummaries(from: scanResults)
    }

    func markScanStale() {
        scanSession.markStale()
        rebuildScanSummaries()
    }

    func clearScanResultsAfterClean(removedURLs: Set<URL>) {
        scanResults.clearAfterClean(removedURLs: removedURLs)
        scanSession.resultsMayBeStale = true
        rebuildScanSummaries()
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        showManagePermissions = false
    }

    func openManagePermissions() {
        showManagePermissions = true
    }

    func setSensitivity(_ value: LeftoverSensitivity) {
        sensitivity = value
    }

    func refreshDiskStats() {
        let stats = SystemStatsService.snapshot()
        diskFreeLabel = stats.diskFreeLabel
        diskUsage = stats.diskUsage
    }

    #if DEBUG
    func resetOnboardingForDebug() {
        hasCompletedOnboarding = false
        showManagePermissions = false
        UserDefaults.standard.set(false, forKey: "mas.onboardingComplete")
    }
    #endif
}

extension View {
    func installAppStores(from state: AppState) -> some View {
        environmentObject(state)
            .environmentObject(state.bookmarks)
            .environmentObject(state.activityLog)
            .environmentObject(state.scanSession)
            .environmentObject(state.scanResults)
            .environmentObject(state.subscription)
    }
}
