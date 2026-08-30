//
//  ContentView.swift
//  mac_cleaner
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: ScanSessionStore

    @State private var showScanComplete = false

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: Binding(
                    get: { appState.selection },
                    set: { appState.navigate(to: $0) }
                )
            )

            Group {
                switch appState.selection {
                case .smartScan:
                    SmartScanView()
                case .applications:
                    ApplicationsView()
                case .spaceCleaner:
                    SpaceCleanerView()
                case .largeFiles:
                    LargeFilesView()
                case .duplicates:
                    DuplicatesView()
                case .spaceLens:
                    DiskTreemapView()
                case .orphans:
                    OrphansView()
                case .activity:
                    ActivityLogView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if showScanComplete {
                    ScanCompleteToast(
                        recoverableBytes: session.summary.recoverableSize,
                        hasMeaningfulRecovery: session.summary.hasMeaningfulRecovery
                    ) {
                        showScanComplete = false
                        if let first = session.summary.topOpportunities.first?.destination {
                            appState.navigate(to: first)
                        } else {
                            appState.navigate(to: .smartScan)
                        }
                    }
                    .padding(.top, AppSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .appCanvas(tint: appState.selection.tint)
        .destinationTint(appState.selection.tint)
        .animation(.easeInOut(duration: 0.32), value: appState.selection)
        .onChange(of: session.completionToken) { _, token in
            guard token != nil else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showScanComplete = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(2400))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        showScanComplete = false
                    }
                }
            }
        }
        .onChange(of: session.isScanning) { _, scanning in
            if scanning {
                withAnimation(.easeOut(duration: 0.15)) {
                    showScanComplete = false
                }
            }
        }
        .sheet(isPresented: $appState.showPaywall) {
            PaywallView()
                .installAppStores(from: appState)
        }
    }
}
