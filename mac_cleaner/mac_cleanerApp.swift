//
//  mac_cleanerApp.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

@main
struct mac_cleanerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .installAppStores(from: appState)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        appState.refreshDiskStats()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Smart Scan") {
                    appState.selection = .smartScan
                    appState.hasCompletedOnboarding = true
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Applications") {
                    appState.selection = .applications
                    appState.hasCompletedOnboarding = true
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Manage Permissions…") {
                    appState.openManagePermissions()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("MacCleaner+", systemImage: "internaldrive") {
            MenuBarMonitor()
                .installAppStores(from: appState)
        }
    }
}

/// Root router — keeps a single stable hierarchy so the window always appears.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .sheet(isPresented: $appState.showManagePermissions) {
                        ManagePermissionsView()
                            .installAppStores(from: appState)
                    }
            } else {
                FolderAccessOnboardingView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appCanvas()
        .background(WindowChromeConfigurator(background: AppColors.background))
        .themedWindowToolbar()
        .preferredColorScheme(appState.preferredColorScheme)
    }
}
