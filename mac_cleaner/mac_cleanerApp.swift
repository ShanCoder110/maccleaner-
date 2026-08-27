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
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        appState.refreshDiskStats()
                    }
                }
        }
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

                Button("Grant Folder Access…") {
                    appState.showPermissionSetup = true
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}

/// Root router — keeps a single stable hierarchy so the window always appears.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding && !appState.showPermissionSetup {
                ContentView()
            } else {
                FolderAccessOnboardingView()
            }
        }
        .background(AppColors.background)
        .preferredColorScheme(appState.preferredColorScheme)
    }
}
