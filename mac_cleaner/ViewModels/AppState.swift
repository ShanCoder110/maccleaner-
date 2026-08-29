//
//  AppState.swift
//  mac_cleaner
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    let bookmarks: BookmarkStore
    let activityLog: ActivityLogStore
    let scanSession: ScanSessionStore
    let subscription: SubscriptionStore

    @Published var sensitivity: LeftoverSensitivity {
        didSet { UserDefaults.standard.set(sensitivity.rawValue, forKey: "mas.sensitivity") }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "mas.appearanceMode") }
    }

    /// First-run only. After this, use `showManagePermissions` for permission changes.
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "mas.onboardingComplete") }
    }

    /// In-app folder permission sheet (Settings, Smart Scan “Manage Permissions”, menu).
    @Published var showManagePermissions: Bool = false
    @Published var showPaywall: Bool = false
    @Published var pendingProDestination: AppDestination?

    @Published var selection: AppDestination = .smartScan
    @Published private(set) var diskFreeLabel: String = "—"
    @Published private(set) var diskUsage: Double = 0

    private var cancellables = Set<AnyCancellable>()

    init(
        bookmarks: BookmarkStore = BookmarkStore(),
        activityLog: ActivityLogStore = ActivityLogStore(),
        scanSession: ScanSessionStore = ScanSessionStore(),
        subscription: SubscriptionStore = SubscriptionStore()
    ) {
        self.bookmarks = bookmarks
        self.activityLog = activityLog
        self.scanSession = scanSession
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

        // One-time migration: re-show first-run onboarding when the grant list changes.
        let flowVersion = 3
        if UserDefaults.standard.integer(forKey: "mas.permissionFlowVersion") < flowVersion {
            UserDefaults.standard.set(flowVersion, forKey: "mas.permissionFlowVersion")
            hasCompletedOnboarding = false
        }

        bookmarks.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.scanSession.markStale()
                }
            }
            .store(in: &cancellables)

        activityLog.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        scanSession.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        subscription.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
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
        await SmartScanRunner.run(bookmarks: bookmarks, session: scanSession) { progress, label in
            self.scanSession.updateProgress(progress, label: label)
        }
        activityLog.log(.scan, "Smart Scan finished")
        refreshDiskStats()
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

    /// Reset first-run flags (useful while debugging).
    #if DEBUG
    func resetOnboardingForDebug() {
        hasCompletedOnboarding = false
        showManagePermissions = false
        UserDefaults.standard.set(false, forKey: "mas.onboardingComplete")
    }
    #endif
}
