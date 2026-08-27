//
//  ContentView.swift
//  mac_cleaner
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: Binding(
                    get: { appState.selection },
                    set: { appState.navigate(to: $0) }
                ),
                onOpenSettings: { appState.selection = .settings }
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
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(AppColors.background)
        .sheet(isPresented: $appState.showPaywall) {
            PaywallView()
                .environmentObject(appState)
        }
    }
}
